# DCS Level 1: Basic Labelling

## Overview

A defence organisation needs to demonstrate DCS Maturity Level 1 (DCS-1) compliance as defined in ACP-240. DCS-1 requires that the majority of new data is labelled with basic handling information -- specifically classification and releasability markings aligned to NATO STANAG 4774 confidentiality metadata label syntax.

Data objects stored in AWS must carry mandatory classification and releasability labels. Objects without valid labels must be detected, quarantined, and reported. All labelling activity must be auditable.

Per ACP-240 para 200: "At maturity level one, DCS-1, data is tagged, or marked, with handling information such as classification and releasability, providing basic labelling."

## Actors

### Data Producer
- **Role**: Uploads classified documents and data objects to cloud storage
- **Responsibility**: Apply correct classification and releasability labels at point of creation
- **Constraint**: Must label data before or during upload; cannot store unlabelled data

### Security Administrator
- **Role**: Defines and maintains the label schema and validation rules
- **Responsibility**: Ensures label values align with STANAG 4774 and national marking policies
- **Constraint**: Must support FVEY national classification equivalencies (ACP-240 Table 0-1)

### Compliance Auditor
- **Role**: Reviews labelling compliance across the data estate
- **Responsibility**: Verifies all data carries valid labels and non-compliance is handled
- **Constraint**: Requires read access to audit logs without access to classified content

## Scenario Flow

### Phase 1: Label Schema Definition

**Context**: The Security Administrator defines the allowed label values based on ACP-240 and STANAG 4774.

**Action**: Configure the system with allowed values for:
- **Classification**: OFFICIAL, SECRET, TOP SECRET (normalised per ACP-240 Table 0-2)
- **Releasability**: GBR, USA, CAN, AUS, NZL, NATO, FVEY (nation codes and COIs)
- **Policy Identifier**: The originating policy namespace (e.g., GBR, USA, NATO)

**Outcome**: Validation rules are deployed and active.

### Phase 2: Data Upload with Labels

**Context**: A Data Producer creates a classified document and uploads it to the data store.

**Action**: The producer attaches labels as metadata during upload:
- `Classification = SECRET`
- `ReleasableTo = GBR,USA,CAN,AUS,NZL`
- `PolicyIdentifier = GBR`

**Outcome**: The object is stored with valid labels and an audit record is created.

### Phase 3: Non-Compliant Upload Detection

**Context**: A Data Producer uploads an object without required labels or with invalid label values.

**Action**: The validation system detects the non-compliance and:
1. Moves the object to a quarantine location
2. Sends a notification to the Security Administrator
3. Logs the non-compliance event

**Outcome**: No unlabelled data persists in the primary data store.

### Phase 4: Compliance Reporting

**Context**: The Compliance Auditor reviews labelling compliance.

**Action**: Query audit logs to determine:
- Total objects processed
- Objects with valid labels (compliant)
- Objects quarantined (non-compliant)
- Label value distribution (classification breakdown)

**Outcome**: Compliance report demonstrating DCS-1 adherence.

## Operational Constraints

1. **Standards Alignment**: Labels must align to STANAG 4774 confidentiality metadata label syntax
2. **Classification Equivalencies**: Must support mapping between national classification systems (ACP-240 Table 0-2)
3. **Automation**: Label validation must be automated -- manual review does not scale
4. **Non-Disruption**: Quarantine process must not lose data; non-compliant objects must be recoverable
5. **Audit Completeness**: Every upload must generate an audit record regardless of compliance outcome

## Technical Challenges

1. **Label Schema Enforcement**: How to enforce mandatory labels at point of upload in a cloud environment?
2. **Value Validation**: How to validate that label values come from the allowed set and are correctly formatted?
3. **Quarantine Without Loss**: How to move non-compliant objects without data loss or race conditions?
4. **Audit Integrity**: How to ensure audit logs cannot be tampered with?
5. **Retroactive Compliance**: How to scan existing unlabelled data for compliance?

## Acceptance Criteria

### AC1: Mandatory Label Presence
- [ ] Every object in the primary data store has a Classification label
- [ ] Every object in the primary data store has a ReleasableTo label
- [ ] Every object in the primary data store has a PolicyIdentifier label
- [ ] Objects uploaded without all required labels are automatically quarantined

### AC2: Label Value Validation
- [ ] Classification values are restricted to the allowed set (OFFICIAL, SECRET, TOP_SECRET)
- [ ] ReleasableTo values are restricted to valid nation codes and COIs
- [ ] PolicyIdentifier values are restricted to valid policy namespaces
- [ ] Objects with invalid label values are quarantined

### AC3: Quarantine Handling
- [ ] Non-compliant objects are copied to a quarantine location
- [ ] Non-compliant objects are removed from the primary data store
- [ ] Quarantined objects retain their original content intact
- [ ] Security Administrator is notified of each quarantine event

### AC4: Audit Trail
- [ ] Every upload generates an audit record (compliant or non-compliant)
- [ ] Audit records include: object identifier, timestamp, label values, compliance decision
- [ ] Audit logs are immutable and tamper-evident
- [ ] Compliance Auditor can query audit logs without accessing object content

### AC5: Standards Alignment
- [ ] Label schema aligns to STANAG 4774 confidentiality metadata label syntax
- [ ] Classification values map to ACP-240 normalised classification equivalencies
- [ ] ReleasableTo values use standard nation codes per ACP-240

## Success Metrics

- **Label Coverage**: All new objects in the primary store carry valid labels
- **Detection Speed**: Non-compliant objects detected and quarantined promptly after upload
- **Audit Completeness**: Every upload event has a corresponding audit record
- **Zero Data Loss**: No objects lost during the quarantine process

## Out of Scope

- Access control enforcement based on labels (covered in DCS Level 2 and broader ABAC implementation)
- Cryptographic protection of data or metadata (covered in DCS Level 3)
- Enhanced metadata beyond classification and releasability (covered in DCS Level 2)
- Cross-domain or cross-organisation data sharing
- ZTDF object creation or manipulation

## Related Scenarios

- **DCS Level 2: Enhanced Labelling** -- extends basic labels with full Minimum Essential Metadata (MEM)
- **DCS Level 3: Cryptographic Protection** -- adds encryption and metadata signing atop labelling

---

**Standards reference:** ACP-240 para 197 (DCS-1: "Majority of New Data Labelled / Basic Labelling"), NATO STANAG 4774 confidentiality metadata label syntax.
