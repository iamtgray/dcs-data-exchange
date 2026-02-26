# Multi-National Intelligence Data Sharing Scenario

## Overview

This scenario demonstrates federated ZTDF/TDF implementation for secure, multi-party intelligence data sharing between NATO member nations with complex, asymmetric access control requirements.

## Participating Nations

### Poland (Data Originator)
- **Role**: Primary sensor data producer
- **Classification System**: NR (No Restriction), NS (NATO Secret), CTS (Cosmic Top Secret)
- **KAS Instance**: Polish Military KAS (PL-KAS)

### United Kingdom
- **Role**: Data processor and enrichment
- **Classification System**: O (Official), S (Secret), TS (Top Secret)
- **Special Access Programs**: GRIFFIN
- **KAS Instance**: UK Ministry of Defence KAS (UK-KAS)

### United States
- **Role**: Data processor and enrichment
- **Classification System**: IL-1 through IL-6 (Impact Levels)
- **Special Access Programs**: HEIMDALL
- **KAS Instance**: US Department of Defense KAS (US-KAS)

## Data Flow Scenario

### Phase 1: Polish Sensor Data Distribution

**Source**: Polish military sensor suite (e.g., radar, SIGINT, reconnaissance)

**Data Classification**: NATO Secret (NS)

**Releasability**: REL TO UK, US

**Access Policy**:
- Any person with NS clearance or above (NS, CTS)
- Applies to all three nations
- No special access program required (raw sensor data)

**TDF Structure**:
```
Polish Sensor Data TDF
├── manifest.json
│   ├── keyAccess[0] → PL-KAS (primary)
│   ├── keyAccess[1] → UK-KAS (federated)
│   ├── keyAccess[2] → US-KAS (federated)
│   └── policy:
│       ├── classification: NS
│       ├── releasability: [UK, US, PL]
│       └── attributes: clearance >= NS
└── payload (encrypted sensor data)
```

**Recipients**: UK and US military intelligence units

### Phase 2: UK Data Enrichment and Re-sharing

**Source**: UK processes Polish data + adds UK intelligence sources

**Data Classification**: UK Secret (S)

**Special Access Program**: WALL (required for all access to enriched data)

**Releasability**: 
- REL TO UK (S+)
- REL TO PL (NS+) 
- REL TO US (IL-6+)

**Access Policies**:
- **For UK personnel**: S clearance + WALL SAP codeword
- **For Polish personnel**: NS clearance + WALL SAP codeword
- **For US personnel**: IL-6 clearance + WALL SAP codeword

**Rationale**: The WALL SAP indicates this data contains enriched intelligence from UK sources. All nations require the WALL codeword access in addition to their respective clearance levels because the enrichment adds sensitive source information beyond the original Polish sensor data.

**TDF Structure**:
```
UK Enriched Data TDF
├── manifest.json
│   ├── keyAccess[0] → UK-KAS (primary)
│   ├── keyAccess[1] → PL-KAS (federated)
│   ├── keyAccess[2] → US-KAS (federated)
│   └── policy:
│       ├── classification: UK-S
│       ├── sap: WALL (required)
│       ├── releasability:
│       │   ├── UK: clearance >= S AND sap.WALL == true
│       │   ├── PL: clearance >= NS AND sap.WALL == true
│       │   └── US: clearance >= IL-6 AND sap.WALL == true
└── payload (encrypted enriched data)
```

**Recipients**: Polish and US military intelligence units (with WALL access)

### Phase 3: US Data Enrichment and Re-sharing

**Source**: US processes Polish data + adds US intelligence sources

**Data Classification**: IL-6

**Special Access Program**: WALL (required for all access to enriched data)

**Releasability**: 
- REL TO US (IL-6+)
- REL TO PL (NS+)
- REL TO UK (TS+)

**Access Policies**:
- **For US personnel**: IL-6 clearance + WALL SAP codeword
- **For Polish personnel**: NS clearance + WALL SAP codeword
- **For UK personnel**: TS clearance + WALL SAP codeword

**Rationale**: The WALL SAP indicates this data contains enriched intelligence from US sources. All nations require the WALL codeword access in addition to their respective clearance levels. Note that UK requires TS (higher than their S requirement for UK-enriched data) because US enrichment includes more sensitive sources.

**TDF Structure**:
```
US Enriched Data TDF
├── manifest.json
│   ├── keyAccess[0] → US-KAS (primary)
│   ├── keyAccess[1] → PL-KAS (federated)
│   ├── keyAccess[2] → UK-KAS (federated)
│   └── policy:
│       ├── classification: IL-6
│       ├── sap: WALL (required)
│       ├── releasability:
│       │   ├── US: clearance >= IL-6 AND sap.WALL == true
│       │   ├── PL: clearance >= NS AND sap.WALL == true
│       │   └── UK: clearance >= TS AND sap.WALL == true
└── payload (encrypted enriched data)
```

**Recipients**: Polish and UK military intelligence units (with WALL access)

## Key Architectural Elements

### Federated KAS Infrastructure

Each nation operates an independent KAS instance:
- **PL-KAS**: Manages Polish KEKs, enforces Polish policies
- **UK-KAS**: Manages UK KEKs, enforces UK policies
- **US-KAS**: Manages US KEKs, enforces US policies

### Attribute Schema Standardization

All three nations must agree on common attribute vocabulary:

**Clearance Levels** (mapped to numeric equivalents for cross-nation comparison):
- Polish: NR=1, NS=2, CTS=3
- UK: O=1, S=2, TS=3
- US: IL-1=1, IL-2=2, IL-3=3, IL-4=4, IL-5=5, IL-6=6

**Special Access Programs** (boolean flags):
- `sap.WALL`: Coalition SAP for enriched intelligence data
  - Applied to any data that has been enriched with national intelligence sources
  - Indicates the data contains more sensitive information than the original sensor data
  - All participating nations must grant WALL access to their personnel who need to view enriched products

**Releasability Markings**:
- `releasability`: Array of nation codes with minimum clearance requirements
- Format: `{nation: "UK", minClearance: "S", sap: ["WALL"]}`

**Nationality** (for policy scoping):
- `nationality`: PL | UK | US

### Policy Enforcement

Each KAS evaluates policies based on:
1. User authentication (via national identity provider)
2. User attributes (clearance level, SAP memberships, nationality)
3. Data attributes (classification, originator, sensitivity)
4. Environmental attributes (time, location, network classification)

### Audit and Compliance

Each KAS maintains independent audit logs:
- All key access requests (successful and denied)
- User identity and attributes at time of access
- Timestamp and source network
- Data object identifier

Logs remain sovereign to each nation but can be shared for coalition audit purposes.

## Data-Centric Security Benefits

1. **Persistent Protection**: Data remains encrypted and policy-enforced regardless of storage location
2. **Granular Access Control**: Different access rules for different nations on the same data object
3. **Sovereignty**: Each nation controls their own KAS and policy decisions
4. **Auditability**: Complete access trail across all three nations
5. **Crypto Agility**: Each KAS can independently upgrade cryptographic algorithms
6. **Offline Capability**: Data can be encrypted offline using asymmetric mode, decrypted online with policy enforcement

## Technical Challenges to Address

### 1. Attribute Mapping

**Challenge**: How do we translate clearance levels across different national systems?

**Solution**: ACP-240 provides standardized classification mapping framework
- Built-in policy translation layer maps different national/alliance classification systems
- Example: "Top Secret" (US) ↔ "Above Secret" (UK) ↔ "CTS" (NATO)
- Acts as bridge between US and NATO standards (STANAGs 4774, 4778, 5636)
- Each KAS implements standard mapping tables defined by ACP-240
- Updates handled through NATO standardization process

**Implementation for our scenario**:
- Polish NS ↔ UK S ↔ US IL-5 (approximate equivalence per ACP-240)
- Each nation's KAS translates incoming policies to local classification system
- Ensures consistent policy enforcement across borders while maintaining national vocabulary

**NOTE**: User will provide new unreleased NATO standard that may replace ACP-240 for future consideration.

### 2. Policy Conflicts

**Challenge**: What happens when policies from different nations conflict?

**Solution**: AnyOf Key Access Pattern
- TDF supports both "AnyOf" and "AllOf" key access patterns via key splitting
- **AnyOf**: Multiple KAS instances where ANY one can independently grant access
  - Each KAS holds a complete wrapped copy of the DEK
  - Client contacts ONE KAS to decrypt
  - Faster, more flexible, better for degraded connectivity
- **AllOf**: Multiple KAS instances where ALL must participate
  - DEK cryptographically split into shares (identified by `sid`)
  - Client must contact ALL KAS instances and reconstruct DEK
  - More secure, ensures multi-party control

**Decision for Coalition Scenario**: Use AnyOf pattern
- UK analyst can contact UK-KAS directly (no need to reach PL-KAS or US-KAS)
- Each nation independently evaluates policy based on their own PDP
- Faster access in operational environments
- Better resilience if one nation's KAS is temporarily unavailable

**Trade-off**: Single nation can unilaterally grant access even if others would deny. Mitigated by:
- Comprehensive audit logs at each KAS
- Standardized policies via ACP-240
- Bilateral agreements on policy interpretation

### 3. TDF Extension and KAS Addition

**Challenge**: How does UK add UK-KAS to a Polish TDF that only contains PL-KAS?

**Solution**: Manifest-Only Update Method
1. UK receives Polish TDF with single keyAccess entry (PL-KAS)
2. UK analyst authenticates to PL-KAS and requests DEK
3. UK wraps the DEK with UK-KAS public key
4. UK extracts manifest.json from TDF ZIP
5. UK adds new keyAccess entry for UK-KAS to manifest
6. UK recalculates policy binding: HMAC(DEK, policy)
7. UK repackages ZIP with updated manifest + unchanged encrypted payload
8. Result: TDF now has two keyAccess entries (PL-KAS and UK-KAS)

**Benefits**:
- No need to re-encrypt payload (efficient for large files)
- Payload integrity maintained
- Original PL-KAS access still works

**Limitation**: Requires online access to PL-KAS to obtain DEK for re-wrapping

### 4. Offline Key Management

**Challenge**: What happens if PL-KAS is unavailable when UK needs to add UK-KAS?

**Problem**: 
- UK cannot decrypt original TDF without PL-KAS access
- UK cannot obtain DEK to wrap for UK-KAS
- Coalition operations may occur in DDIL (Denied, Degraded, Intermittent, Limited) environments

**Potential Solutions** (requires further analysis):
1. **Asymmetric Mode Pre-Configuration**: Poland encrypts with UK's public key from creation
2. **Pre-shared Wrapped Keys**: Poland provides wrapped DEKs offline before deployment
3. **Cached Authorization**: UK caches successful PL-KAS responses for offline re-wrapping
4. **Trusted Key Escrow**: Third-party holds DEK copies (politically sensitive)

**Status**: Critical operational issue requiring architectural decision. See next.md for detailed analysis.

### 5. Key Revocation

**Challenge**: How do we handle compromised keys in a federated environment?

[To be addressed]

### 6. Time Synchronization

**Challenge**: Ensuring consistent policy evaluation across time zones

[To be addressed]

### 7. Network Connectivity

**Challenge**: Handling degraded connectivity to foreign KAS instances during normal operations

[To be addressed]

### 8. Trust Establishment

**Challenge**: How do KAS instances verify each other's authenticity?

[To be addressed]

---

*Next Steps: Design the technical architecture to implement this scenario*
