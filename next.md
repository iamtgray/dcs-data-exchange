# Next Steps: Offline Key Management Architecture

## Current State

We've established a multi-national ZTDF data sharing scenario with:
- Three nations (Poland, UK, US) each operating independent KAS instances
- AnyOf key access pattern for operational flexibility
- Manifest-only update method for adding new KAS entries to existing TDFs

## Critical Unresolved Issue: Offline Key Management

### The Problem

**Scenario**: Polish sensor data is encrypted with only PL-KAS. UK receives the TDF in a forward operating base with intermittent connectivity. UK needs to:
1. Decrypt and process the Polish data
2. Enrich it with UK intelligence sources
3. Add UK-KAS to the TDF for UK personnel access
4. Re-share with Poland and US

**Blocker**: If PL-KAS is unreachable (network degraded, tactical environment, denied connectivity):
- UK cannot decrypt the original Polish TDF
- UK cannot obtain the DEK needed to wrap it for UK-KAS
- UK cannot add UK-KAS keyAccess entry to manifest
- Mission fails due to technical limitation

### Why This Matters

Coalition operations frequently occur in DDIL (Denied, Degraded, Intermittent, Limited) environments:
- Forward operating bases with satellite-only connectivity
- Contested electromagnetic spectrum
- Cross-domain transfers through air-gapped systems
- Tactical edge computing scenarios
- Submarine/maritime operations with periodic connectivity

**Requirement**: Data sharing must work even when origin nation's KAS is temporarily unreachable.

## Proposed Solutions Analysis

### Option 1: Asymmetric Mode with Pre-Distributed Public Keys

**Concept**: Poland encrypts data with UK's and US's public keys from the start (offline encryption mode).

**How it works**:
1. Poland obtains UK-KAS and US-KAS public keys in advance (during mission planning)
2. Polish sensor system encrypts data with DEK
3. Polish system wraps DEK with:
   - PL-KAS public key (for Polish access)
   - UK-KAS public key (for UK access)
   - US-KAS public key (for US access)
4. TDF created with three keyAccess entries, all offline
5. UK can decrypt using UK-KAS without ever contacting PL-KAS

**Advantages**:
- Fully offline encryption
- No dependency on PL-KAS availability for UK/US access
- Supported by ZTDF specification
- Each nation maintains sovereignty over their KAS

**Disadvantages**:
- Poland must know recipients in advance (no ad-hoc sharing)
- Cannot add new recipients without re-encrypting entire TDF
- Larger manifest (multiple wrapped keys from creation)
- Requires pre-coordination and key distribution

**Operational Fit**: Good for planned operations with known coalition partners

### Option 2: Pre-Shared Wrapped DEK Bundles

**Concept**: Poland pre-generates and shares wrapped DEK bundles offline before deployment.

**How it works**:
1. During mission planning, Poland generates DEKs for anticipated data
2. Poland wraps each DEK with PL-KAS, UK-KAS, and US-KAS public keys
3. Poland provides UK with "DEK bundle" file containing wrapped keys
4. When Polish sensor creates TDF, it uses DEK from pre-generated pool
5. UK can locally add UK-KAS keyAccess entry using pre-shared wrapped DEK
6. UK updates manifest without contacting PL-KAS

**Advantages**:
- Enables offline manifest updates
- Poland doesn't need to know exact recipients at encryption time
- UK can add UK-KAS independently
- Smaller TDF files (only one keyAccess initially)

**Disadvantages**:
- Complex key management (tracking which DEK used for which TDF)
- DEK pool exhaustion risk
- Requires secure offline key distribution channel
- Synchronization challenges (which DEK goes with which TDF?)

**Operational Fit**: Moderate - adds significant complexity

### Option 3: Cached KAS Authorization Tokens

**Concept**: UK caches successful PL-KAS authorization responses for offline replay.

**How it works**:
1. During online phase, UK analyst accesses Polish TDF via PL-KAS
2. UK-KAS caches the rewrapped DEK response from PL-KAS
3. When offline, UK can use cached DEK to:
   - Decrypt Polish TDFs with same policy
   - Wrap DEK for UK-KAS
   - Add UK-KAS keyAccess entry
4. Cache expires based on policy TTL

**Advantages**:
- Transparent to Polish systems
- Works with existing TDF structure
- Enables time-limited offline operations
- Simpler than pre-shared keys

**Disadvantages**:
- Only works for TDFs with previously-seen policies
- Cache expiration creates operational windows
- Security risk if cache compromised
- Doesn't help with first-time access to new data

**Operational Fit**: Good for sustained operations with recurring data patterns

### Option 4: Federated Key Escrow Service

**Concept**: Trusted third-party service holds encrypted DEK copies for coalition operations.

**How it works**:
1. NATO or coalition command operates escrow KAS
2. Poland wraps DEK with both PL-KAS and Escrow-KAS
3. UK can request DEK from Escrow-KAS when PL-KAS unavailable
4. Escrow-KAS enforces same policies as PL-KAS
5. All escrow access logged and auditable

**Advantages**:
- Solves offline problem completely
- Maintains policy enforcement
- Centralized audit trail
- Works for ad-hoc sharing

**Disadvantages**:
- Politically sensitive (who controls escrow?)
- Single point of failure/compromise
- Trust model challenges
- May violate national sovereignty requirements

**Operational Fit**: Requires high-level political agreement

### Option 5: Hybrid Approach - Tiered Access

**Concept**: Combine asymmetric pre-distribution for planned ops with online access for ad-hoc sharing.

**How it works**:
1. **Planned Operations**: Poland uses asymmetric mode with pre-distributed public keys
   - Mission-critical data encrypted with all coalition KAS keys
   - Fully offline capable
2. **Ad-Hoc Sharing**: Poland uses symmetric mode with only PL-KAS
   - Requires online access to PL-KAS
   - More flexible for unplanned recipients
3. **Degraded Mode**: UK uses cached authorizations for time-limited offline access

**Advantages**:
- Flexible - supports both planned and ad-hoc scenarios
- Balances security and operational needs
- Leverages existing ZTDF capabilities
- No new infrastructure required

**Disadvantages**:
- Complexity - two different workflows
- Training burden on operators
- Policy decisions about which mode to use

**Operational Fit**: Best - matches real-world operational patterns

### Option 6: Dual-Mode Encryption - PKI for Tactical, TDF for Strategic

**Concept**: Use different encryption systems based on operational context and connectivity tier.

**How it works**:
1. **Tactical Edge (Unit-to-Unit)**:
   - Use traditional PKI with certificate-based encryption (S/MIME, PGP, or military PKI)
   - Certificates distributed offline during mission planning
   - Certificate validation via CRL (Certificate Revocation List) or cached OCSP (Online Certificate Status Protocol) responses
   - Fast, lightweight, works completely offline
   - Example: Polish forward unit → UK forward unit sensor data sharing

2. **Strategic/Coalition (Cross-Domain)**:
   - Use TDF/ZTDF for data shared beyond tactical units
   - When data needs to go "up and out" to coalition partners
   - Requires reliable connectivity to KAS instances
   - Full ABAC policy enforcement and audit trails
   - Example: UK enriched intelligence → Polish HQ, US intelligence community

3. **Transition Points**:
   - Tactical units collect/share data using PKI encryption
   - When data reaches unit with reliable comms (battalion HQ, ship, air base)
   - Gateway system re-encrypts from PKI to TDF format
   - TDF then shared across coalition networks

**Advantages**:
- Matches operational reality (different security needs at different echelons)
- Tactical edge stays lightweight and offline-capable
- Strategic sharing gets full data-centric security benefits
- Each system optimized for its use case
- Proven technologies (PKI is mature, TDF is standardized)

**Disadvantages**:
- Two encryption systems to manage
- Gateway/translation points are potential vulnerabilities
- Data must be decrypted and re-encrypted at transition (performance hit)
- Certificate management overhead (CRLs, OCSP, expiration)
- Policy translation between PKI access control and TDF ABAC

**Operational Fit**: Excellent - mirrors actual military network architecture (tactical vs strategic networks)

**Example Flow**:
```
Polish Sensor (tactical edge)
    ↓ PKI encryption (Polish unit cert)
UK Forward Unit (tactical edge)
    ↓ Process + enrich
UK Battalion HQ (gateway with reliable comms)
    ↓ Decrypt PKI, re-encrypt as TDF with UK-KAS + PL-KAS
Coalition Network (strategic)
    ↓ TDF with full ABAC policies
Polish HQ, US Intelligence (strategic consumers)
```

**Certificate Management for Offline**:
- Pre-distribute certificates during mission planning
- CRLs downloaded before deployment (valid for mission duration)
- OCSP responses cached for offline validation
- Certificate expiration aligned with mission timelines
- Emergency revocation via out-of-band channels (radio, courier)

**TDF Benefits at Strategic Level**:
- Persistent policy enforcement across organizational boundaries
- Granular ABAC (clearance + SAP + nationality + releasability)
- Comprehensive audit trails for coalition accountability
- Dynamic policy updates (revoke access to already-shared data)
- Crypto agility (upgrade algorithms without breaking compatibility)

## Recommended Approach

**Primary**: Option 6 (Dual-Mode: PKI for Tactical, TDF for Strategic)
**Secondary**: Option 5 (Hybrid Tiered Access within TDF)
**Fallback**: Option 1 (Asymmetric Mode) for critical pre-planned operations

### Rationale

Coalition operations have different security and connectivity requirements at different echelons:

**Tactical Edge** (forward units, ships, aircraft):
- Intermittent/denied connectivity
- Need immediate data sharing with nearby units
- Lightweight encryption overhead
- Known participants (unit-to-unit within mission)
- PKI certificates work perfectly here

**Strategic Level** (HQ, intelligence community, cross-border):
- Reliable connectivity to KAS infrastructure
- Complex access control requirements (clearance + SAP + nationality)
- Unknown/dynamic recipients (share with coalition partners as needed)
- Audit and compliance requirements
- TDF provides necessary granularity and persistence

**Real-World Analogy**: 
- Tactical = SIPR (Secret IP Router Network) - closed, known participants
- Strategic = Coalition networks - open, dynamic participants, complex policies

This dual-mode approach is actually how many military networks already operate - different encryption at different classification levels and network tiers. We're just formalizing it with PKI at tactical and TDF at strategic.

### Implementation Requirements

1. **Gateway Architecture**: Design secure transition points between PKI and TDF domains
2. **Certificate Management**: Establish PKI infrastructure for tactical units (issuance, CRL distribution, OCSP caching)
3. **Policy Translation**: Map PKI certificate attributes to TDF ABAC attributes
4. **Encryption Transition**: Define secure decrypt/re-encrypt procedures at gateways
5. **Operator Training**: Clear procedures for which mode to use at each echelon
6. **Audit Continuity**: Link PKI access logs with TDF audit trails for end-to-end visibility
7. **Performance Optimization**: Minimize latency at gateway transition points

### Security Considerations

**Gateway Vulnerabilities**:
- Gateways decrypt and re-encrypt (data briefly in plaintext)
- Must be hardened, monitored, and audited
- Consider HSM (Hardware Security Module) for key operations
- Implement strict access controls and physical security

**Certificate Revocation**:
- CRLs may be stale in offline environments
- Define acceptable staleness window (24h? 7 days?)
- Emergency revocation procedures for compromised certificates
- OCSP stapling for recent validation proof

**Policy Consistency**:
- Ensure PKI access control aligns with TDF policies
- Certificate attributes must map to TDF ABAC attributes
- Example: Certificate OU="UK-SECRET" → TDF attribute clearance="S"

## Questions for Next Session

1. Should we design the architecture with dual-mode (PKI tactical + TDF strategic) as primary approach?
2. Where should the PKI→TDF gateways be located (battalion HQ? brigade? theater command)?
3. What certificate attributes do we need to map to TDF ABAC attributes?
4. How do we handle audit trail continuity across the PKI→TDF transition?
5. What's the acceptable CRL/OCSP staleness window for tactical operations?
6. Should gateways be nation-specific (UK gateway, US gateway) or coalition-operated?
7. Do we need to address the unreleased NATO standard before finalizing architecture?
8. How does data flow back down from strategic to tactical (TDF→PKI)?

## Architecture Design Next Steps

Once offline key management approach is decided:
1. Design detailed KAS federation architecture
2. Define manifest update workflows
3. Specify policy evaluation logic for each nation
4. Design audit log aggregation across KAS instances
5. Address remaining challenges (key revocation, time sync, trust establishment)
6. Create sequence diagrams for each data flow scenario
7. Define API contracts between KAS instances (if needed)

---

*Status: Awaiting decision on offline key management approach before proceeding with detailed architecture*
