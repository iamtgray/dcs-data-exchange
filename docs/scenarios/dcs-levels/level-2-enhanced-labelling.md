# DCS Level 2: Enhanced Labelling

## Overview

A defence organisation needs to demonstrate DCS Maturity Level 2 (DCS-2) compliance as defined in ACP-240. DCS-2 extends DCS-1 basic labelling by adding the full Minimum Essential Metadata (MEM) set to data objects, enabling richer characterisation, discoverability, and attribute-based access control (ABAC).

Per ACP-240 para 200: "At level two, DCS-2, enhanced labelling is supported with the elements of basic labelling adding additional metadata to characterise the data, such as date of creation, publisher, subject etc."

The MEM is defined in ACP-240 Table 0-2 and aligned to NATO STANAGs 4774 and 5636. Beyond richer metadata, DCS-2 demonstrates how these attributes enable ABAC policy enforcement -- where access decisions are made dynamically based on matching user attributes (clearance, nationality) against data attributes (classification, releasability).

## Actors

### Data Producer
- **Role**: Uploads classified documents with full MEM applied
- **Responsibility**: Apply all required metadata at point of creation
- **Constraint**: Must populate all mandatory MEM fields

### SECRET-Cleared UK Analyst
- **Role**: Accesses data up to SECRET classification with UK releasability
- **Attributes**: Clearance=SECRET, Nationality=GBR
- **Constraint**: Cannot access TOP SECRET data or data not releasable to GBR

### OFFICIAL-Cleared NATO Partner Analyst
- **Role**: Accesses data at OFFICIAL classification with NATO releasability
- **Attributes**: Clearance=OFFICIAL, Nationality=NATO_PARTNER
- **Constraint**: Cannot access SECRET or TOP SECRET data; limited to NATO-releasable data

### Security Administrator
- **Role**: Defines MEM schema, ABAC policies, and attribute mappings
- **Responsibility**: Maintains alignment with ACP-240 MEM definition and clearance hierarchies

### Compliance Auditor
- **Role**: Reviews metadata completeness and access decision logs
- **Responsibility**: Verifies full MEM compliance and ABAC enforcement

## Scenario Flow

### Phase 1: MEM Schema Definition

**Context**: The Security Administrator defines the full MEM per ACP-240 Table 0-2.

**Action**: Configure the system to require and validate these metadata fields:

| # | Attribute | Description | ABAC Enforced |
|---|-----------|-------------|:---:|
| 1 | Classification | Confidentiality level (OFFICIAL, SECRET, TOP_SECRET) | Yes |
| 2 | PolicyIdentifier | Originating policy namespace (GBR, USA, NATO) | |
| 3 | CreationDateTime | When the confidentiality label was created | |
| 4 | ReleasableTo | Nation codes and COIs for release (GBR, FVEY, NATO) | Yes |
| 5 | AdditionalSensitivity | Caveats and handling codewords | |
| 6 | Administrative | Administrative handling instructions | |
| 7 | UniqueIdentifier | Globally unique object identifier | |
| 8 | Creator | Identity of the data creator | |
| 9 | DateTimeCreated | When the data object was created | |
| 10 | Publisher | Publishing organisation | |
| 11 | Title | Descriptive title of the data object | |

**Outcome**: MEM validation rules and ABAC policies are deployed.

### Phase 2: Data Upload with Full MEM

**Context**: A Data Producer creates a classified document and uploads it with complete MEM.

**Action**: The producer attaches all MEM fields during upload. The system validates:
1. All mandatory MEM fields are present
2. All values conform to allowed schemas
3. Classification and ReleasableTo values are valid per STANAG 4774
4. Additional metadata fields (Creator, Publisher, Title, etc.) are populated

**Outcome**: Object stored with full MEM; audit record created.

### Phase 3: ABAC Access Decision -- Granted

**Context**: The SECRET-cleared UK Analyst requests access to a document labelled `Classification=SECRET, ReleasableTo=GBR,USA,CAN,AUS,NZL`.

**Action**: The system evaluates the ABAC policy:
- User Clearance (SECRET) >= Object Classification (SECRET): PASS
- User Nationality (GBR) in Object ReleasableTo (GBR,USA,CAN,AUS,NZL): PASS

**Outcome**: Access granted. Decision logged with user attributes, object attributes, and timestamp.

### Phase 4: ABAC Access Decision -- Denied

**Context**: The OFFICIAL-cleared NATO Partner Analyst requests access to the same SECRET document.

**Action**: The system evaluates the ABAC policy:
- User Clearance (OFFICIAL) >= Object Classification (SECRET): FAIL

**Outcome**: Access denied. Decision logged with reason for denial.

### Phase 5: Metadata Completeness Reporting

**Context**: The Compliance Auditor reviews MEM compliance across the data estate.

**Action**: Query the metadata catalog to determine:
- Objects with complete MEM vs incomplete MEM
- MEM field population rates
- Access decision summary (grants vs denials by classification level)

**Outcome**: Compliance report demonstrating DCS-2 adherence.

## Operational Constraints

1. **MEM Alignment**: Metadata fields must align to ACP-240 Table 0-2 and NATO STANAGs 4774/5636
2. **Clearance Hierarchy**: Classification levels form a hierarchy (TOP_SECRET > SECRET > OFFICIAL) per ACP-240 Table 0-1
3. **S3 Tag Limits**: AWS S3 object tags are limited to 10 tags of 256 characters each; extended metadata requires a separate catalog
4. **Dynamic Evaluation**: Access decisions must be evaluated at request time, not pre-computed
5. **Audit Completeness**: Every access attempt (granted and denied) must be logged

## Technical Challenges

1. **Metadata Storage**: How to store 11+ MEM fields when S3 tags are limited to 10?
2. **ABAC at Scale**: How to enforce attribute-based access efficiently across many objects and users?
3. **Clearance Hierarchy**: How to implement hierarchical classification matching in IAM conditions?
4. **Metadata Integrity**: How to ensure MEM values cannot be modified without detection?
5. **Retroactive Enrichment**: How to add enhanced metadata to existing DCS-1 labelled objects?

## Acceptance Criteria

### AC1: Full MEM Compliance
- [ ] Every object carries all mandatory MEM fields per ACP-240 Table 0-2
- [ ] MEM values conform to allowed schemas and value sets
- [ ] Objects with incomplete MEM are flagged for remediation
- [ ] MEM validation occurs automatically at upload time

### AC2: ABAC Policy Enforcement
- [ ] Access granted when user clearance >= object classification AND user nationality in releasability
- [ ] Access denied when user clearance < object classification
- [ ] Access denied when user nationality not in object releasability
- [ ] Clearance hierarchy correctly implemented (TOP_SECRET > SECRET > OFFICIAL)

### AC3: Access Decision Audit
- [ ] Every access attempt (granted and denied) generates an audit record
- [ ] Audit records include: user identity, user attributes, object identifier, object attributes, decision, timestamp
- [ ] Denial reasons are recorded (clearance insufficient, nationality not in releasability, etc.)
- [ ] Audit logs are queryable for compliance reporting

### AC4: Metadata Catalog
- [ ] Extended MEM stored in a searchable metadata catalog
- [ ] Core ABAC attributes (Classification, ReleasableTo) stored as S3 object tags for policy enforcement
- [ ] Metadata catalog and S3 tags are kept in sync
- [ ] Metadata is queryable for discoverability (per VAULTIS goals in ACP-240)

### AC5: Standards Alignment
- [ ] MEM fields align to ACP-240 Table 0-2 normalised metadata definitions
- [ ] Classification values support FVEY equivalencies per ACP-240 Table 0-1
- [ ] ABAC policy logic aligns to ACP-240 access control model using Classification and ReleasableTo as core attributes

## Success Metrics

- **MEM Completeness**: All new objects carry the full MEM set
- **ABAC Accuracy**: All access decisions correctly enforce clearance hierarchy and releasability
- **Audit Coverage**: Every access attempt has a corresponding audit record with full attribution
- **Discoverability**: Objects are findable via metadata queries without accessing content

## Out of Scope

- Cryptographic protection of data or metadata (covered in DCS Level 3)
- Cross-domain data transfer or guard functions
- ZTDF object creation or manipulation
- Federated identity across multiple organisations
- Real-time streaming data access control

## Related Scenarios

- **DCS Level 1: Basic Labelling** -- prerequisite; provides the core Classification and ReleasableTo labels
- **DCS Level 3: Cryptographic Protection** -- extends DCS-2 by encrypting data and signing metadata

---

**Standards reference:** ACP-240 para 198 (DCS-2: "Enhanced Labelling"), ACP-240 Table 0-2 (MEM definition), NATO STANAGs 4774/5636, ACP-240 para 247 (Classification and ReleasableTo as core ABAC attributes).
