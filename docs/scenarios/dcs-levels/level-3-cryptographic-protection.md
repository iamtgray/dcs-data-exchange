# DCS Level 3: Cryptographic Protection

## Overview

A defence organisation needs to demonstrate DCS Maturity Level 3 (DCS-3) compliance as defined in ACP-240. DCS-3 provides cryptographic protection of data, enabling both confidentiality through encryption and integrity through signing of metadata. This is the most mature DCS level and provides full data-centric security capability.

Per ACP-240 para 199-200: "DCS Maturity Level 3 (DCS-3) -- Cryptographic Protection -- By 2033. Finally, at maturity level three, DCS-3, cryptographic protection is provided, enabling both confidentiality through encryption of the data, and integrity through signing of the metadata."

Per ACP-240 para 202: "A native file must be transformed into a DCS object to achieve DCS-3." In production, this means creating ZTDF objects. This demonstration uses AWS KMS envelope encryption to implement the core DCS-3 concepts: per-classification encryption keys, cryptographic separation between classification levels, HMAC signing of metadata, and ABAC enforcement via KMS key policies.

## Actors

### Data Producer
- **Role**: Encrypts classified data using the appropriate classification key
- **Responsibility**: Select correct classification, provide full MEM, initiate encryption
- **Constraint**: Must have permission to use the KMS key for the target classification

### Data Consumer
- **Role**: Requests decryption of classified data
- **Attributes**: Clearance level and nationality determine which KMS keys they can access
- **Constraint**: Can only decrypt data at or below their clearance level

### Key Custodian
- **Role**: Manages KMS keys and key policies
- **Responsibility**: Ensure cryptographic separation between classification levels
- **Constraint**: Key policies must enforce ABAC; key material must not be extractable

### Security Administrator
- **Role**: Defines ABAC policies enforced through KMS key policies
- **Responsibility**: Maintain alignment between key policies and classification hierarchy

### Compliance Auditor
- **Role**: Reviews cryptographic operation audit trails
- **Responsibility**: Verify all encrypt/decrypt operations are logged and authorised
- **Constraint**: Can review audit logs without access to plaintext data or key material

## Scenario Flow

### Phase 1: Key Hierarchy Establishment

**Context**: The Key Custodian creates per-classification KMS keys with ABAC-enforcing key policies.

**Action**: Create three KMS keys with key policies:
- **dcs-official-key**: Usable by roles with Clearance = OFFICIAL, SECRET, or TOP_SECRET
- **dcs-secret-key**: Usable by roles with Clearance = SECRET or TOP_SECRET
- **dcs-top-secret-key**: Usable by roles with Clearance = TOP_SECRET only

Key policies use `aws:PrincipalTag/Clearance` conditions to enforce the classification hierarchy.

**Outcome**: Cryptographic separation between classification levels established.

### Phase 2: Data Encryption (Envelope Encryption)

**Context**: A Data Producer encrypts a SECRET document.

**Action**:
1. Producer calls KMS `GenerateDataKey` using `dcs-secret-key` to obtain a plaintext Data Encryption Key (DEK) and its KMS-wrapped (encrypted) form
2. Producer encrypts the document payload using the plaintext DEK (AES-256-GCM)
3. Producer HMAC-signs the metadata (Classification, ReleasableTo, MEM fields) using a signing key derived from the DEK
4. Producer stores in S3: encrypted payload as object body, wrapped DEK as metadata, HMAC signature as metadata, classification and releasability as object tags
5. Plaintext DEK is discarded from memory

**Outcome**: Data is cryptographically protected. The wrapped DEK can only be unwrapped by KMS using the `dcs-secret-key`, which requires appropriate clearance.

### Phase 3: Data Decryption -- Authorised

**Context**: A SECRET-cleared UK analyst requests the encrypted document.

**Action**:
1. Consumer retrieves encrypted object and wrapped DEK from S3
2. Consumer calls KMS `Decrypt` with the wrapped DEK
3. KMS evaluates the key policy: Consumer's Clearance (SECRET) is in the allowed set for `dcs-secret-key` -- PASS
4. KMS returns plaintext DEK
5. Consumer verifies the HMAC signature on metadata to confirm integrity
6. Consumer decrypts the payload using the plaintext DEK

**Outcome**: Data decrypted successfully. Full audit trail in CloudTrail (KMS operations) and application logs.

### Phase 4: Data Decryption -- Denied

**Context**: An OFFICIAL-cleared analyst requests the same SECRET document.

**Action**:
1. Consumer retrieves encrypted object and wrapped DEK from S3
2. Consumer calls KMS `Decrypt` with the wrapped DEK
3. KMS evaluates the key policy: Consumer's Clearance (OFFICIAL) is NOT in the allowed set for `dcs-secret-key` -- DENY
4. KMS returns AccessDeniedException

**Outcome**: Decryption denied. The consumer never receives the plaintext DEK or data. Denial logged in CloudTrail.

### Phase 5: Metadata Integrity Verification

**Context**: An attacker or misconfiguration modifies the classification tag on an encrypted object (e.g., changes SECRET to OFFICIAL).

**Action**: During decryption, the consumer:
1. Retrieves the stored HMAC signature from object metadata
2. Recomputes the HMAC over the current metadata values
3. Compares: recomputed HMAC does not match stored HMAC -- INTEGRITY FAILURE
4. Decryption aborted; integrity violation logged

**Outcome**: Metadata tampering detected. Even if tags are modified, the cryptographic binding (HMAC) reveals the change.

## Operational Constraints

1. **ACP-240 Alignment**: Encryption approach must align to ACP-240 key encryption concepts (paras 203-212)
2. **Envelope Encryption**: Must use envelope encryption pattern (DEK encrypts data, KEK wraps DEK) as per ZTDF architecture
3. **Key Separation**: Each classification level must have a separate KMS key -- no key sharing across levels
4. **Metadata Signing**: Metadata integrity must be cryptographically verifiable (HMAC per ACP-240 para 247)
5. **Audit**: All KMS operations must be logged via CloudTrail for compliance
6. **No Key Export**: KMS key material must never leave the KMS boundary

## Technical Challenges

1. **Envelope Encryption Implementation**: How to implement GenerateDataKey + local AES encryption in Lambda?
2. **HMAC Key Derivation**: How to derive a signing key from the DEK for metadata integrity?
3. **Key Policy ABAC**: How to express classification hierarchy in KMS key policy conditions?
4. **Lambda Crypto Dependencies**: How to package cryptographic libraries (e.g., `cryptography`) for Lambda?
5. **Large Payload Support**: KMS direct encrypt is limited to 4KB; envelope encryption needed for larger payloads
6. **Key Rotation**: How to rotate KMS keys without breaking access to previously encrypted data?

## Acceptance Criteria

### AC1: Per-Classification Encryption Keys
- [ ] Separate KMS keys exist for OFFICIAL, SECRET, and TOP SECRET classification levels
- [ ] Key policies enforce that only roles with sufficient clearance can use each key
- [ ] Classification hierarchy is correctly enforced (TOP_SECRET can use all keys, OFFICIAL can only use dcs-official-key)
- [ ] Key material is not extractable from KMS

### AC2: Envelope Encryption
- [ ] Data is encrypted using a DEK generated by KMS GenerateDataKey
- [ ] DEK is wrapped (encrypted) by the classification-appropriate KMS key
- [ ] Encrypted payload stored as S3 object body; wrapped DEK stored as S3 object metadata
- [ ] Plaintext DEK is not persisted anywhere after encryption completes

### AC3: Metadata Integrity (HMAC Signing)
- [ ] Metadata (Classification, ReleasableTo, MEM fields) is HMAC-signed during encryption
- [ ] HMAC signature is stored alongside the encrypted object
- [ ] Metadata integrity is verified during decryption before returning plaintext
- [ ] Tampering with metadata tags is detected and reported

### AC4: Access Enforcement via KMS
- [ ] SECRET-cleared users can decrypt OFFICIAL and SECRET data
- [ ] OFFICIAL-cleared users cannot decrypt SECRET or TOP SECRET data
- [ ] TOP_SECRET-cleared users can decrypt data at all classification levels
- [ ] Access denials result in KMS AccessDeniedException with no data exposure

### AC5: Comprehensive Crypto Audit Trail
- [ ] All KMS GenerateDataKey operations are logged in CloudTrail
- [ ] All KMS Decrypt operations (successful and denied) are logged in CloudTrail
- [ ] Application-level audit records include: user, object, classification, operation, outcome, timestamp
- [ ] Audit trail enables reconstruction of all cryptographic operations on any object

### AC6: Data Protection Persistence
- [ ] Encrypted data remains protected regardless of S3 bucket policy changes
- [ ] Encrypted data remains protected even if copied to another location
- [ ] Only KMS key access (enforced by key policy) can unlock the data
- [ ] Protection is independent of network or perimeter security

## Success Metrics

- **Cryptographic Coverage**: All new data objects are encrypted using the appropriate classification key
- **Access Enforcement**: KMS key policies correctly enforce classification hierarchy for all decrypt attempts
- **Integrity Detection**: All metadata tampering attempts are detected via HMAC verification
- **Audit Completeness**: Every cryptographic operation has corresponding CloudTrail and application log entries
- **Key Separation**: No cross-classification key usage possible

## Out of Scope

- Full ZTDF object creation (this demo uses AWS-native envelope encryption to demonstrate DCS-3 concepts)
- Federated key management across multiple organisations or KAS instances
- Post-quantum cryptographic algorithms
- Hardware Security Module (HSM) backed keys (AWS KMS provides equivalent key protection)
- Real-time streaming encryption
- Cross-domain guard functions

## Related Scenarios

- **DCS Level 1: Basic Labelling** -- prerequisite; provides Classification and ReleasableTo labels used in encryption decisions
- **DCS Level 2: Enhanced Labelling** -- prerequisite; provides full MEM that is HMAC-signed for integrity
- **Scenario 01: Coalition Strategic Intelligence Sharing** -- DCS-3 with federated KAS is the production target for multi-nation sharing

---

**Standards reference:** ACP-240 para 199 (DCS-3: "Cryptographic Protection"), ACP-240 paras 203-212 (key encryption concepts), ACP-240 para 247 (HMAC metadata signing). Production implementations use the ZTDF format with STANAG 4774 marking and STANAG 4778 metadata binding.
