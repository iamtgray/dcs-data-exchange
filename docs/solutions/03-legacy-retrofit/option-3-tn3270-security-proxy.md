# Option 3: TN3270 Security Proxy (DCS Level 2 enforcement)

## Solution overview

This solution deploys a TN3270-aware proxy between the CICS transaction server and users' terminal emulators. The proxy intercepts 3270 data streams, identifies which screen and fields are being displayed, looks up classification labels from the shadow label store (Option 1) and user attributes from the attribute store (Option 2), and dynamically redacts or hides fields the user is not authorised to see.

This is the enforcement layer that makes DCS Level 1 labels operationally meaningful for interactive users.

## Scenario reference

**Addresses**: Scenario 03 -- Legacy System DCS Retrofit
**DCS Level**: Level 2 (Access Control / Enforcement)
**Dependencies**: Option 1 (shadow label store), Option 2 (user attribute store)
**Scope**: Interactive 3270 sessions only. Batch/export data flows are covered by Option 4.

## How 3270 data streams work

Understanding the proxy requires understanding how 3270 terminal sessions work, because this is not HTTP and the interception model is fundamentally different from a web application firewall.

### The 3270 protocol

A 3270 session is a stateful conversation between CICS and a terminal emulator:

1. **CICS sends a data stream** containing: a Write command (erase screen or write to specific positions), field attribute bytes (protected/unprotected, highlighted, hidden, numeric-only), and field data (the actual text values).

2. **The terminal emulator renders** the data stream as a fixed-format screen. Fields appear at specific row/column positions. Protected fields are display-only. Unprotected fields accept user input.

3. **The user types and presses an AID key** (Enter, PF1-PF24, PA1-PA3). The emulator sends back only the modified (unprotected) fields.

4. **CICS processes the input** and sends a new data stream (next screen or updated current screen).

The critical property is that screens are deterministic: a given CICS transaction always renders the same BMS map with fields at the same positions. The supply request detail screen always has `DEST_UNT` at row 12, column 35. This predictability is what makes proxy-based filtering feasible.

### What the proxy sees

The proxy sits in the TN3270 TCP stream between CICS and the terminal emulator:

```
┌──────────┐     TN3270      ┌──────────────┐     TN3270      ┌──────────┐
│          │    data stream   │              │    data stream   │          │
│   CICS   │ ──────────────> │  DCS Proxy   │ ──────────────> │ Terminal │
│          │                  │              │                  │ Emulator │
│          │ <────────────── │              │ <────────────── │          │
│          │   user input     │              │   user input     │          │
└──────────┘                  └──────────────┘                  └──────────┘
                                     │
                              ┌──────┴──────┐
                              │             │
                        ┌─────▼─────┐ ┌────▼─────┐
                        │  Shadow   │ │  User    │
                        │  Label    │ │ Attribute│
                        │  Store    │ │  Store   │
                        │ (Opt. 1)  │ │ (Opt. 2) │
                        └───────────┘ └──────────┘
```

The proxy parses the outbound 3270 data stream (CICS → terminal) and can:
- Read all field positions and values
- Identify which BMS map is being displayed
- Modify field values (replace with redacted text)
- Change field attributes (set to "hidden" or "non-display")
- Pass through the inbound stream (terminal → CICS) unmodified

## How it works

### Phase 1: Screen mapping (prerequisite)

Before the proxy can filter anything, every CICS transaction screen must be mapped. This is the "archaeology" work that depends on the developers who know the system.

For each of the ~90 CICS transactions:

1. **Identify all BMS maps** used by the transaction (some transactions use multiple screens -- list view, detail view, edit view, confirmation)
2. **Document field positions** for each map: row, column, length, and what data the field contains
3. **Map fields to DB2 columns**: which field on the screen corresponds to which column in which table
4. **Classify field sensitivity**: using the same rules as the shadow label store, determine the baseline sensitivity of each field position
5. **Identify the record key**: which field(s) on the screen contain the primary key needed to look up labels from the shadow store

The output is a screen map configuration file:

```yaml
transaction: SRQD
description: "Supply Request Detail"
bms_map: SRQDMAP1
record_table: JLTS.SUPPLY_REQUESTS
key_fields:
  - screen_position: {row: 3, col: 15, length: 10}
    db_column: REQ_ID

fields:
  - screen_position: {row: 5, col: 15, length: 40}
    db_column: ITEM_DESC
    default_classification: NU

  - screen_position: {row: 7, col: 15, length: 8}
    db_column: QTY_RQST
    default_classification: NR

  - screen_position: {row: 9, col: 15, length: 30}
    db_column: DEST_UNT
    default_classification: NS

  - screen_position: {row: 11, col: 15, length: 10}
    db_column: DLVR_DTE
    default_classification: NC

  - screen_position: {row: 13, col: 15, length: 60}
    db_column: REMARKS
    default_classification: DYNAMIC  # requires label lookup
```

**Effort estimate**: With ~90 transactions and an average of 2-3 screens per transaction, this is roughly 200-250 screen maps. A developer familiar with the BMS maps could document 5-10 screens per day. This is 4-10 weeks of work for one person, and it's the critical path.

**Screen identification**: The proxy identifies which BMS map is being displayed by matching the static text pattern on the screen (titles, labels, field prompts) against known signatures. Each screen map includes a fingerprint:

```yaml
fingerprint:
  - {row: 1, col: 5, text: "SUPPLY REQUEST DETAIL"}
  - {row: 3, col: 5, text: "REQUEST ID:"}
```

### Phase 2: Session establishment

When a user connects through the proxy:

1. Proxy intercepts the TN3270 connection
2. User authenticates to RACF normally (proxy passes through the login sequence)
3. Proxy captures the RACF user ID from the login data stream
4. Proxy queries the user attribute store (Option 2) to retrieve clearance, nationality, SAPs, role
5. Proxy caches user attributes for the session duration
6. Session proceeds normally -- user sees the JLTS main menu

If the user ID is not found in the attribute store, the proxy applies a default policy: restrict to NATO UNCLASSIFIED data only. This is fail-secure.

### Phase 3: Screen filtering

On every screen render (every time CICS sends a data stream to the user):

1. **Parse the data stream**: Extract field positions and values from the 3270 data stream
2. **Identify the screen**: Match static text against screen map fingerprints
3. **Extract the record key**: Read the primary key field(s) from the screen data
4. **Look up labels**: Query the shadow label store for the record's row-level and field-level classifications
5. **Evaluate policy**: For each field on the screen, compare the field's classification against the user's attributes:
    - User clearance ≥ field classification? → display
    - User nationality in field's releasability? → display
    - User has required SAP? → display
    - Otherwise → redact
6. **Modify the data stream**: Replace redacted field values with `[REDACTED]` or set the field attribute to non-display
7. **Forward the modified data stream** to the terminal emulator

**Policy evaluation logic** (simplified):

```
function canUserSeeField(user, fieldLabel):
    # Classification level check
    if classificationRank(user.clearance) < classificationRank(fieldLabel.classification):
        return DENY

    # National caveat check
    if fieldLabel.releasability is not null:
        if user.nationality not in fieldLabel.releasability:
            return DENY

    # SAP check
    if fieldLabel.requiredSAPs is not empty:
        if not user.sapMemberships.containsAll(fieldLabel.requiredSAPs):
            return DENY

    return ALLOW
```

### Phase 4: List screen handling

List screens (where multiple records are displayed in a scrollable table) require special handling:

- Each row in the list is a separate record with its own labels
- The proxy must look up labels for every visible record on the screen
- Records the user cannot see at all (row-level classification exceeds clearance) are replaced with blank rows or "[ACCESS DENIED]"
- Records the user can partially see have individual fields redacted
- Scrolling (PF7/PF8) triggers a new data stream, and the proxy filters each page independently

**Performance consideration**: A list screen showing 20 records requires 20 label lookups. With DB2 on the same mainframe, this should complete in single-digit milliseconds if the shadow tables are properly indexed. The proxy should batch these lookups into a single SQL query using an `IN` clause on the primary keys visible on screen.

### Phase 5: Audit logging

Every filtering decision is logged:

```
{
  "timestamp": "2026-03-24T14:32:15Z",
  "user_id": "JDUPON01",
  "user_clearance": "NC",
  "user_nationality": "FRA",
  "transaction": "SRQD",
  "record_key": "SR-00421",
  "fields_displayed": ["ITEM_DESC", "QTY_RQST"],
  "fields_redacted": ["DEST_UNT", "DLVR_DTE", "REMARKS"],
  "redaction_reasons": {
    "DEST_UNT": "classification NS exceeds user clearance NC",
    "DLVR_DTE": "classification NC but REL_TO:GBR,USA excludes FRA",
    "REMARKS": "label pending review, default DENY"
  }
}
```

## Handling edge cases

### Unmapped screens

If the proxy encounters a screen it can't identify (no fingerprint match), it has two options:

- **Fail-open**: Pass the screen through unfiltered. Operationally convenient but defeats the purpose.
- **Fail-closed**: Block the screen entirely, showing a "screen not available" message. Secure but disruptive.

**Recommendation**: Fail-closed for the initial deployment, with an aggressive screen mapping effort to minimise unmapped screens. Once coverage reaches 100% of actively used transactions, this becomes a non-issue. New transactions added to JLTS (rare -- fewer than 10 changes per year) must be mapped before deployment.

### Free-text fields

Fields like `REMARKS` may contain anything. The shadow label store may have a label for the field, but the label was assigned based on content analysis at labeling time. If the content changes (user updates the remarks field), the label may be stale until the next sync cycle.

**Mitigation**: Free-text fields in sensitive tables default to the row-level classification. If the row is NS, the remarks field is treated as NS regardless of its individual field label. This is conservative (may over-restrict) but safe.

### Print and file transfer

Some 3270 emulators support local print and file transfer (IND$FILE). The proxy must intercept these as well:

- **Print**: The proxy filters the print data stream the same way it filters screen data
- **File transfer**: IND$FILE transfers are blocked or filtered depending on policy. This is a data exfiltration vector that needs careful handling.

### Batch processing

The proxy does not cover batch processing. Batch jobs run under the `JLTS-BATCH` service account and produce reports and data feeds that bypass the 3270 layer entirely. This is addressed by Option 4 (batch/export gateway).

## Advantages

1. **Zero changes to COBOL**: CICS doesn't know the proxy exists
2. **Immediate user impact**: Users see filtered data from day one of deployment
3. **Field-level granularity**: Can redact individual fields within a screen
4. **Deterministic screens**: Fixed-format 3270 screens are easier to filter than dynamic web UIs
5. **Centralised enforcement**: Single enforcement point for all interactive users
6. **Auditable**: Every filtering decision is logged with full context

## Disadvantages

1. **Screen mapping effort**: 200-250 screens must be documented before the proxy is useful -- this is the critical path
2. **Maintenance burden**: Any change to JLTS screens (new transactions, modified BMS maps) requires updating the screen maps
3. **Performance overhead**: Parsing and filtering every data stream adds latency (target: <50ms per screen)
4. **Complexity**: TN3270 protocol parsing is specialised work -- not many developers have this skill set
5. **Batch gap**: Does not cover batch reports or data feeds (requires Option 4)
6. **Single point of failure**: If the proxy fails, users either lose access (fail-closed) or lose filtering (fail-open)
7. **Doesn't cover the web emulator directly**: The Java-based web 3270 emulator connects via TN3270, so the proxy covers it, but any future web modernisation would need a different approach

## Acceptance criteria coverage

From Scenario 03:

- ✅ **AC1: Automatic Content Labeling** -- Consumes labels from Option 1
- ✅ **AC2: User Attribute Integration** -- Consumes attributes from Option 2
- ✅ **AC3: Policy-Based Access Control** -- Evaluates user attributes against content labels
- ✅ **AC4: Dynamic Content Filtering** -- Full, partial (redacted), and denied access
- ✅ **AC5: Granular Filtering** -- Field-level filtering on 3270 screens
- ⚠️ **AC6: Multiple Content Types** -- Handles structured screen data; documents/images not applicable to 3270
- ✅ **AC7: Seamless Integration** -- No changes to legacy application, transparent to CICS
- ⚠️ **AC8: Performance** -- Target <50ms per screen; depends on label lookup speed and screen complexity
- ✅ **AC9: Comprehensive Audit Trail** -- Full logging of every filtering decision
- ✅ **AC10: Policy Management** -- Screen maps and policy rules are configuration, not code
- ✅ **AC11: Accuracy and Reliability** -- Deterministic filtering based on pre-computed labels
- ✅ **AC12: Mixed Sensitivity Handling** -- Field-level filtering handles mixed sensitivity rows

## Technology stack

- TN3270 protocol parser/proxy (custom or based on existing open-source TN3270 libraries)
- Screen map configuration (YAML or similar)
- DB2 client for label and attribute lookups
- Audit log store (syslog, database, or SIEM integration)
- High-availability deployment (active/passive or active/active proxy instances)

## Implementation complexity

**Complexity**: High

The TN3270 protocol parsing is specialised but well-understood (there are open-source 3270 libraries). The screen mapping is labour-intensive but not technically difficult. The hard parts are:
- Achieving reliable screen identification across all transaction variants
- Handling edge cases (scrolling, multi-screen transactions, error screens)
- Performance optimisation for label lookups on list screens
- High-availability deployment (the proxy is now in the critical path for all users)
- Testing across all 90 transactions with representative data

## Operational fit

This is the component that delivers visible security improvement to users and auditors. It's also the most complex to build and the one with the highest operational risk (it's in the critical path for all interactive access).

The recommended deployment approach is phased:
1. Deploy proxy in pass-through mode (no filtering) to validate screen identification
2. Enable filtering for one low-risk transaction (e.g., reference data lookup) with a small user group
3. Expand to additional transactions incrementally, validating each one
4. Full deployment once all actively used transactions are mapped and tested

---

*Enforcement layer for interactive JLTS access. Intercepts 3270 data streams and applies field-level filtering based on pre-computed labels and user attributes. Must be paired with Option 1 (labels) and Option 2 (user attributes). Does not cover batch/export data flows (see Option 4).*
