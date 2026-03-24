# Option 1: Shadow Label Store (DCS Level 1)

## Solution overview

This solution creates a parallel set of DB2 metadata tables that hold classification labels for every record in JLTS, keyed to the primary keys of existing tables. The COBOL application continues to operate unchanged -- it never reads from or writes to the shadow tables. A separate classification process populates and maintains the labels.

This is the foundational component that all other DCS retrofit options depend on. Without labels on the data, neither access control (Level 2) nor encryption (Level 3) can function.

## Scenario reference

**Addresses**: Scenario 03 -- Legacy System DCS Retrofit
**DCS Level**: Level 1 (Labeling)
**Dependency**: None (this is the foundation)
**Dependents**: Options 2, 3, and 4 all consume labels from this store

## How it works

### Shadow table design

For each JLTS table that contains data requiring classification, a corresponding shadow table is created in a separate DB2 schema (`JLTS_DCS`). The shadow tables hold only primary key references and classification metadata -- no copies of the actual data.

```
Original table: JLTS.SUPPLY_REQUESTS
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│ REQ_ID   │ ITEM_DESC│ QTY_RQST │ DEST_UNT │ DLVR_DTE │
│ (PK)     │          │          │          │          │
├──────────┼──────────┼──────────┼──────────┼──────────┤
│ SR-00421 │ JP-8 ... │ 5000     │ 3 PARA.. │ 2026-04..│
└──────────┴──────────┴──────────┴──────────┴──────────┘

Shadow table: JLTS_DCS.SUPPLY_REQUESTS_LABELS
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│ REQ_ID   │ ROW_CLF  │ FIELD_CLF│ NATL_CAV │ LABEL_SRC│ LABEL_DTE│
│ (FK)     │          │ (JSON)   │          │          │          │
├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│ SR-00421 │ NS       │ {see below}│ NULL   │ RULE-007 │ 2026-03..│
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

### Label granularity

The shadow tables support three levels of granularity simultaneously:

**Row-level classification** (`ROW_CLF`): The overall classification of the record, determined by the highest sensitivity field. This is the primary label used for most access control decisions.

**Field-level classification** (`FIELD_CLF`): A structured field (stored as VARCHAR containing a simple key-value format compatible with DB2 for z/OS) mapping individual column names to their classification. Used for fine-grained filtering where different fields in the same row have different sensitivities.

```json
{
  "ITEM_DESC": "NU",
  "QTY_RQST": "NR",
  "DEST_UNT": "NS",
  "DLVR_DTE": "NC"
}
```

**National caveats** (`NATL_CAV`): Releasability restrictions (e.g., `REL_TO:FRA,GBR` or `REL_TO:NATO`). Stored separately because they're orthogonal to classification level.

### Label provenance

Every label records how it was determined:

- `LABEL_SRC`: Which rule, process, or reviewer assigned the label (e.g., `RULE-007`, `ML-BATCH-20260315`, `MANUAL-REVIEW-JSMITH`)
- `LABEL_DTE`: When the label was assigned or last reviewed
- `LABEL_CONF`: Confidence score (1.0 for rule-based, 0.0-1.0 for ML-assisted, 1.0 for manually reviewed)
- `REVIEW_STS`: Whether the label has been manually reviewed (`PENDING`, `REVIEWED`, `DISPUTED`)

This provenance chain is critical for audit and for prioritising manual review effort.

### Classification approaches

The shadow tables are populated through a tiered classification strategy:

**Tier 1 -- Table-level defaults** (covers ~200,000 records immediately):
Reference and administrative tables are classified wholesale. The `COUNTRY_CODES` table is NATO UNCLASSIFIED. The `UNIT_REGISTRY` table is NATO RESTRICTED. These are deterministic, require no analysis, and can be applied in a single batch run.

**Tier 2 -- Field-based rules** (covers ~200,000 more records):
Rules based on which fields are populated and what table the record is in. "Any record in `UNIT_MOVEMENTS` with a non-null `GRID_REF` is at least NATO SECRET." "Any record in `SUPPLY_REQUESTS` where `ITEM_DESC` matches ammunition categories is NATO CONFIDENTIAL." These rules are defined by subject matter experts and applied by batch SQL.

**Tier 3 -- Content analysis** (covers remaining ~80,000 records):
Records where classification depends on the content of free-text fields (remarks, descriptions, notes). This is where ML/LLM-assisted classification or manual review is needed. These records are flagged with `REVIEW_STS = 'PENDING'` and queued for the classification engine (discussed in the separate context document).

**Tier 4 -- Composite/contextual** (ongoing refinement):
Records where the combination of fields creates a higher classification than any individual field. "Fuel delivery + specific unit + specific date = operational tempo indicator = SECRET." These rules are the hardest to define and are refined over time based on subject matter expert input.

### Ongoing synchronisation

New data enters JLTS daily through interactive CICS transactions and nightly batch feeds. The shadow label store must stay in sync:

**For batch feeds** (8 national systems, nightly):
A post-processing job runs after each national feed completes. It identifies new and changed records (using DB2 log-based change capture or timestamp comparison) and applies Tier 1 and Tier 2 rules automatically. Records requiring Tier 3 analysis are queued for review.

**For interactive transactions** (CICS data entry):
A DB2 trigger or a periodic "catch-up" batch job (running every 15-30 minutes) detects new records created through CICS and applies default labels. Since CICS transactions create records in known tables with known field patterns, Tier 1 and 2 rules cover most cases.

**For archived data** (15 million records):
Archived data is classified in background batch runs over weeks/months, prioritised by access frequency. Records that haven't been accessed in 5+ years get table-level defaults. Records accessed in the last year get full field-level classification.

### What this does NOT provide

- **Cryptographic binding**: Labels are stored in DB2 tables, not cryptographically bound to the data per STANAG 4778. A DB2 administrator could modify labels. This is basic Level 1, not assured Level 1.
- **Access enforcement**: Labels exist but nothing prevents a user from querying the original JLTS tables directly. Enforcement requires the TN3270 proxy (Option 2) or batch gateway (Option 4).
- **Encryption**: Data remains unencrypted in DB2. Labels describe sensitivity but don't protect the data.

## Advantages

1. **Zero impact on COBOL application**: Separate schema, separate tables, no changes to existing code or queries
2. **Incremental deployment**: Can label tables one at a time, starting with the most sensitive
3. **Auditable**: Every label has provenance (who/what assigned it, when, confidence level)
4. **Foundation for Level 2 and 3**: Other components consume these labels without needing their own classification logic
5. **Reversible**: Shadow tables can be dropped without affecting JLTS operation
6. **Queryable**: Labels can be analysed, reported on, and quality-checked using standard SQL

## Disadvantages

1. **Not cryptographically bound**: Labels can be tampered with by anyone with DB2 admin access
2. **Synchronisation lag**: New records may be unlabeled for minutes (interactive) to hours (batch) after creation
3. **Classification accuracy**: Only as good as the rules and the classification engine -- garbage in, garbage out
4. **Maintenance burden**: Rules need updating as data patterns change, new tables are added, or classification policies evolve
5. **DB2 resource consumption**: Additional tablespace, I/O, and batch processing time on the mainframe
6. **Institutional knowledge dependency**: Defining accurate field-level rules requires the three developers who understand the schema

## Acceptance criteria coverage

From Scenario 03:

- ✅ **AC1: Automatic Content Labeling** -- Tiered classification strategy covers all record types
- ⚠️ **AC2: User Attribute Integration** -- Not addressed (this is a labeling solution, not an enforcement solution)
- ⚠️ **AC3: Policy-Based Access Control** -- Labels enable this but don't enforce it
- ⚠️ **AC4: Dynamic Content Filtering** -- Labels enable this but don't enforce it
- ✅ **AC5: Granular Filtering** -- Field-level labels support document, section, and field-level granularity
- ✅ **AC6: Multiple Content Types** -- Handles structured data; text documents in DB2 BLOBs would need additional handling
- ✅ **AC7: Seamless Integration** -- No changes to legacy application
- ✅ **AC8: Performance** -- Batch labeling has no impact on interactive performance
- ✅ **AC9: Comprehensive Audit Trail** -- Label provenance provides full audit chain
- ✅ **AC10: Policy Management** -- Rules can be versioned, tested, and updated
- ⚠️ **AC11: Accuracy and Reliability** -- Depends on classification engine quality (separate discussion)
- ✅ **AC12: Mixed Sensitivity Handling** -- Field-level labels handle mixed sensitivity rows

## Technology stack

- IBM DB2 for z/OS (existing) -- shadow tables in new schema
- JCL batch jobs -- rule application and synchronisation
- DB2 change data capture or timestamp-based detection -- sync mechanism
- Rule definition format (SQL-based or configuration file) -- classification rules
- Optional: external classification engine for Tier 3 content analysis

## Implementation complexity

**Complexity**: Medium

The DB2 schema design and Tier 1/2 rule application are straightforward mainframe work. The hard parts are:
- Defining accurate Tier 2 rules (requires deep schema knowledge)
- Building the Tier 3 classification pipeline (separate effort)
- Ensuring synchronisation doesn't miss records
- Quality assurance of labels at scale

## Operational fit

This is the most conservative, lowest-risk starting point for DCS retrofit. It adds capability (labels exist where they didn't before) without changing anything about how JLTS currently operates. It's also the prerequisite for everything else -- you can't build the proxy or the batch gateway without labels to consume.

The main risk is that labels without enforcement create a false sense of security. Having labels in shadow tables is necessary but not sufficient -- they only become useful when something reads them and acts on them.

---

*Foundation component for JLTS DCS retrofit. Labels the data; does not enforce access control or provide encryption. Must be paired with Options 2, 3, or 4 for operational security benefit.*
