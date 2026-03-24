# Context: classification engine for JLTS legacy DCS retrofit

This document provides context for a focused discussion on how to automatically classify and label data in a legacy NATO logistics system. It is a companion to a parallel discussion about where to store those labels and how to apply DCS Levels 1, 2, and 3 to the system.

## The System: JLTS

The NATO Joint Logistics Tracking System (JLTS) is a fictional but representative legacy application:

- **Built**: 2004, for ISAF logistics coordination
- **Technology**: ~340,000 lines of COBOL-85, IBM z/OS mainframe, CICS transaction server, DB2 for z/OS
- **Database**: 147 tables, ~380 GB active data, ~2.1 TB archived, all in EBCDIC
- **Users**: ~850 across 14 NATO nations (logistics staff, liaison officers, procurement, auditors)
- **Security model**: Binary RACF access (you're in or you're out). No granular access control. Designed for a single security domain (NATO SECRET).

## The Data

JLTS holds logistics data of varying actual sensitivity, but almost none of it is labeled:

| Data Category | Actual Sensitivity | Records |
|---|---|---|
| Unit locations and movements | NATO SECRET | ~45,000 |
| Supply request details | NATO CONFIDENTIAL to SECRET | ~120,000 |
| Vendor contract terms | NATO RESTRICTED | ~8,000 |
| Maintenance schedules | NATO RESTRICTED to CONFIDENTIAL | ~65,000 |
| Personnel assignments (logistics roles) | NATO SECRET + national caveats | ~12,000 |
| National contribution data | NATO CONFIDENTIAL + REL TO [nation] | ~30,000 |
| Administrative/reference data | NATO UNCLASSIFIED | ~200,000 |
| Archived operational data | Mixed (NS/NC/NR) | ~15 million |

A `CLF_LVL` column exists in several tables but is only ~30% populated, and of those values ~40% are inaccurate (per a 2019 audit sample).

## The classification problem

Regardless of where we store the labels (that's being discussed separately), we need to determine the correct classification for ~480,000 active records and potentially 15 million archived records. This is the problem to focus on.

### What makes this hard

1. **Mixed sensitivity within single rows**: A supply request record contains an unclassified item description (`ITEM_DESC`: "Diesel fuel, JP-8, 5000L") alongside a SECRET destination (`DEST_UNIT`: "3rd Battalion, FOB Wolverine, Grid Ref 42S ND 1234 5678"). The row doesn't have one classification -- different fields have different sensitivities.

2. **Context-dependent classification**: "500 units of 5.56mm ammunition" is RESTRICTED as a supply item. But if the destination is a specific forward operating base and the delivery date is next Tuesday, the combination becomes SECRET because it reveals operational tempo and unit readiness.

3. **National caveats**: National contribution data (what each nation is providing) often carries releasability restrictions. "France is providing 12 Leclerc MBTs to Operation X" is REL TO FRA + mission participants, not REL TO all NATO. These caveats aren't recorded anywhere in the data -- they're "understood" by the users.

4. **Temporal sensitivity**: Some data degrades in sensitivity over time. Last week's convoy route is SECRET. Last year's convoy route is probably RESTRICTED. A convoy route from 2008 might be UNCLASSIFIED. There's no systematic rule for this.

5. **Abbreviations and codes**: The data is full of military abbreviations, unit designators, grid references, and NATO stock numbers. A classification engine needs to understand that "42S ND 1234 5678" is a grid reference (and therefore location-sensitive) and that "3 PARA" is a unit designator (and therefore operationally sensitive).

6. **EBCDIC encoding**: All data is stored in EBCDIC, not ASCII/UTF-8. Any classification tooling needs to handle character set conversion.

7. **Schema archaeology**: Column names are 8-character abbreviations (`MVMT_TYP`, `DEST_UNT`, `QTY_RQST`). Understanding what data is in each column requires the (incomplete) data dictionary or institutional knowledge from the development team.

### Classification granularity question

We need to decide at what level to classify:

- **Table level**: "The UNIT_MOVEMENTS table is NATO SECRET." Simple but crude -- the admin/reference columns in that table are UNCLASSIFIED.
- **Row level**: "This specific supply request is NATO CONFIDENTIAL." Better, but misses that some fields in the row are more sensitive than others.
- **Field level**: "The DEST_UNIT field in this row is NATO SECRET, but the ITEM_DESC field is UNCLASSIFIED." Most accurate, but dramatically more complex and more labels to manage.
- **Derived/composite**: "This row is NATO SECRET because the combination of ITEM_DESC + DEST_UNIT + DLVR_DATE reveals operational intent." Hardest to automate.

### Approaches to explore

Here are the approaches we want to think through for actually determining the correct classification:

**Rule-based classification**: Define rules like "any record in UNIT_MOVEMENTS is at least NS" or "any record with a non-null GRID_REF field is NS." Fast, deterministic, auditable. But brittle -- rules need to cover every case, and the combinatorial/contextual cases are hard to express as rules.

**ML/NLP-assisted classification**: Use trained models to analyse free-text fields (remarks, descriptions, notes) and identify sensitive content. Could catch things rules miss. But: training data is the labeled data we don't have, the text is full of military jargon and abbreviations, and the consequences of misclassification are serious (this isn't spam filtering).

**LLM-assisted classification**: Use large language models to understand context and classify records. LLMs handle jargon and context better than traditional NLP. But: LLM hallucination risk in a security-critical context, data sovereignty concerns (can we send NATO data to an LLM?), and the need for human review of outputs.

**Hybrid approach**: Rules for the easy/deterministic cases (table-level defaults, known-sensitive fields), ML/LLM for ambiguous free-text fields, human review for edge cases and validation. Probably the realistic answer, but the question is what the right mix is.

**Manual classification with tooling**: Give subject matter experts a tool that presents records and asks them to classify. Accurate but doesn't scale to 480,000 records (let alone 15 million archived). Could work as a validation layer on top of automated approaches.

### Key questions for this discussion

1. What's the right granularity for JLTS? Table, row, field, or composite?
2. Can we define a practical rule set that covers 80%+ of records, leaving only the hard cases for other approaches?
3. Is LLM-assisted classification viable given data sovereignty constraints? Could an on-premise LLM work?
4. How do we handle the temporal sensitivity problem?
5. How do we handle national caveats that aren't recorded in the data?
6. What's the validation/QA process? How do we know the labels are correct?
7. What's the ongoing classification process for new data entering JLTS daily?
8. How do we handle the 15 million archived records -- do we even need to classify them all?

### Constraints

- Cannot modify the COBOL application
- Cannot change the DB2 schema (adding new tables is acceptable, altering existing tables is not)
- Classification must be accurate enough for operational security (this isn't a "best effort" exercise)
- Must handle EBCDIC data
- Any tooling that processes the data must operate within the NATO SECRET security domain
- The three developers who understand the system are a bottleneck for institutional knowledge

## DCS context

For background on Data-Centric Security levels:

- **DCS Level 1 (Labeling)**: Metadata describing data sensitivity, ideally cryptographically bound to the data (STANAG 4778). This is what we're trying to achieve.
- **DCS Level 2 (Access Control)**: Using labels to enforce attribute-based access control. Depends on Level 1 being in place.
- **DCS Level 3 (Encryption)**: Cryptographic protection of data with policy-based key access. Depends on Levels 1 and 2.

The classification engine is a prerequisite for all three levels. Without accurate labels, nothing else works.

---

*This context document is designed to be self-contained for a focused discussion on the classification engine problem. The parallel discussion covers where labels are stored and how DCS Levels 1-3 are applied to JLTS.*
