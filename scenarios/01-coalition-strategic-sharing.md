# Scenario 01: Coalition Strategic Intelligence Sharing

## Overview

Three NATO member nations need to share and collaboratively enrich intelligence data across organizational boundaries with complex, asymmetric access control requirements. Data originates from one nation, is enriched by others, and must be accessible based on clearance levels and special access programs.

## Actors

### Poland (Data Originator)
- **Role**: Primary sensor data producer
- **Classification System**: NR (No Restriction), NS (NATO Secret), CTS (Cosmic Top Secret)
- **Infrastructure**: National key management infrastructure

### United Kingdom (Data Processor)
- **Role**: Data enrichment with UK intelligence sources
- **Classification System**: O (Official), S (Secret), TS (Top Secret)
- **Infrastructure**: UK Ministry of Defence key management infrastructure

### United States (Data Processor)
- **Role**: Data enrichment with US intelligence sources
- **Classification System**: IL-1 through IL-6 (Impact Levels)
- **Infrastructure**: US Department of Defense key management infrastructure

## Scenario Flow

### Phase 1: Initial Data Distribution

**Context**: Polish military operates sensor suite (radar, SIGINT, reconnaissance) producing classified intelligence.

**Action**: Poland encrypts and distributes sensor data to UK and US military intelligence units.

**Data Classification**: NATO Secret (NS)

**Access Requirements**:
- Any person with NS clearance or above (NS, CTS)
- Applies to personnel from all three nations
- No special access program required

### Phase 2: UK Data Enrichment

**Context**: UK receives Polish sensor data and enriches it with UK intelligence sources (HUMINT, additional SIGINT, analysis).

**Action**: UK produces enriched intelligence product and shares with Poland and US.

**Data Classification**: UK Secret (S) + Special Access Program "WALL"

**Access Requirements**:
- **UK personnel**: S clearance or above
- **Polish personnel**: NS clearance + WALL SAP codeword
- **US personnel**: IL-6 clearance + WALL SAP codeword

**Rationale**: WALL SAP indicates data contains enriched intelligence from UK sources. Higher clearance required for US personnel due to sensitivity of UK sources.

### Phase 3: US Data Enrichment

**Context**: US receives Polish sensor data and enriches it with US intelligence sources.

**Action**: US produces enriched intelligence product and shares with Poland and UK.

**Data Classification**: IL-6 + Special Access Program "WALL"

**Access Requirements**:
- **US personnel**: IL-6 clearance or above
- **Polish personnel**: NS clearance + WALL SAP codeword
- **UK personnel**: TS clearance + WALL SAP codeword

**Rationale**: WALL SAP indicates data contains enriched intelligence from US sources. Higher clearance required for UK personnel (TS vs S) due to sensitivity of US sources.

## Operational Constraints

1. **Network Connectivity**: All parties have reliable connectivity to their national key management infrastructure
2. **Infrastructure**: Each nation operates independent key management systems
3. **Sovereignty**: Each nation must maintain control over their own cryptographic keys
4. **Interoperability**: Systems must work across different national classification systems
5. **Auditability**: All access to data must be logged for compliance and accountability
6. **Dynamic Recipients**: Ability to add new recipients after initial encryption
7. **Policy Updates**: Ability to update access policies on already-shared data

## Technical Challenges

1. **Classification Mapping**: How to translate clearance levels across different national systems (NS ↔ S ↔ IL-6)?
2. **Federated Key Management**: How do multiple independent key management systems collaborate?
3. **Policy Enforcement**: How to enforce complex, nation-specific access rules on shared data?
4. **Data Enrichment**: How does UK add their key management to Polish-encrypted data?
5. **Audit Aggregation**: How to create unified audit trail across three independent systems?
6. **Policy Conflicts**: What happens when different nations' policies conflict?
7. **Key Revocation**: How to revoke access in a federated environment?

## Acceptance Criteria

### AC1: Cross-Border Data Sharing
- [ ] Polish sensor data encrypted once can be decrypted by authorized UK and US personnel
- [ ] No need to create separate encrypted copies for each nation
- [ ] Data protection persists regardless of storage location

### AC2: Classification System Interoperability
- [ ] Polish NS clearance maps to equivalent UK and US clearance levels
- [ ] UK S clearance maps to equivalent Polish and US clearance levels
- [ ] US IL-6 clearance maps to equivalent Polish and UK clearance levels
- [ ] Mapping is standardized and consistent across all systems

### AC3: Granular Access Control
- [ ] UK-enriched data accessible to UK personnel with S clearance
- [ ] UK-enriched data accessible to Polish personnel with NS + WALL SAP
- [ ] UK-enriched data accessible to US personnel with IL-6 + WALL SAP
- [ ] US-enriched data accessible to US personnel with IL-6 clearance
- [ ] US-enriched data accessible to Polish personnel with NS + WALL SAP
- [ ] US-enriched data accessible to UK personnel with TS + WALL SAP
- [ ] Access denied to personnel without required clearance/SAP combination

### AC4: Federated Key Management
- [ ] Each nation operates independent key management infrastructure
- [ ] No nation has access to another nation's private keys
- [ ] Any nation's key management system can independently grant access
- [ ] System continues to function if one nation's infrastructure is temporarily unavailable

### AC5: Dynamic Recipient Addition
- [ ] UK can add UK key management to Polish-encrypted data without re-encrypting payload
- [ ] US can add US key management to Polish-encrypted data without re-encrypting payload
- [ ] Process works for large files (multi-GB) efficiently

### AC6: Comprehensive Audit Trail
- [ ] Every access attempt logged (successful and denied)
- [ ] Logs include: user identity, timestamp, data identifier, access decision
- [ ] Each nation maintains independent audit logs
- [ ] Audit logs can be aggregated for coalition-wide visibility

### AC7: Policy Persistence
- [ ] Access policies travel with the data
- [ ] Policies enforced regardless of where data is stored
- [ ] Policies can be updated after data is shared
- [ ] Policy updates affect already-distributed data

### AC8: Sovereignty and Control
- [ ] Each nation controls access decisions for their personnel
- [ ] No central authority required for access decisions
- [ ] Each nation can independently revoke access for their personnel

## Success Metrics

- **Time to Share**: < 5 minutes from encryption to recipient access
- **Access Decision Latency**: < 2 seconds for policy evaluation
- **Audit Completeness**: 100% of access attempts logged
- **Interoperability**: Works across all three national systems without manual intervention
- **Scalability**: Supports 10+ nations without architectural changes

## Out of Scope

- Offline/disconnected operations (covered in Scenario 02)
- Tactical edge communications (covered in Scenario 02)
- Real-time streaming data
- Data at rest encryption for storage systems
- Network-level security (VPNs, firewalls, etc.)

---

*This scenario focuses on strategic-level intelligence sharing with reliable connectivity. For tactical/offline scenarios, see Scenario 02.*
