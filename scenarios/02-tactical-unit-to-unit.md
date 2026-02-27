# Scenario 02: Tactical Unit-to-Unit Communications

## Overview

Forward-deployed military units from allied nations need to share operational data in denied, degraded, intermittent, and limited (DDIL) connectivity environments. Units must exchange time-sensitive information without reliance on strategic infrastructure or continuous network connectivity.

## Actors

### Polish Forward Reconnaissance Unit
- **Location**: Forward operating base near contested border
- **Connectivity**: Satellite link (intermittent, 2-4 hour windows)
- **Classification Authority**: NATO Secret (NS)
- **Equipment**: Tactical radios, mobile sensors, ruggedized laptops

### UK Infantry Battalion
- **Location**: 15km from Polish unit, different sector
- **Connectivity**: Tactical radio network, occasional satellite
- **Classification Authority**: UK Secret (S)
- **Equipment**: Tactical radios, battlefield management systems

### US Marine Expeditionary Unit
- **Location**: 30km from Polish unit, coastal sector
- **Connectivity**: Ship-to-shore communications, tactical radio
- **Classification Authority**: IL-5 (Impact Level 5)
- **Equipment**: Tactical radios, mobile command post

## Scenario Flow

### Phase 1: Polish Reconnaissance Data

**Context**: Polish reconnaissance unit observes enemy movement patterns over 48 hours. Data includes:
- Sensor readings (radar, thermal imaging)
- Observation reports
- Tactical maps with annotations
- Time-series movement data

**Action**: Polish unit needs to share reconnaissance data with UK and US units for coordinated response.

**Constraints**:
- No connectivity to Polish national key management infrastructure
- Satellite window in 6 hours (too late for tactical response)
- Data must be shared via tactical radio network (limited bandwidth)
- UK and US units also lack connectivity to their national infrastructure

**Data Classification**: NATO Secret (NS)

**Access Requirements**:
- Allied personnel with NS clearance or equivalent
- Valid for 72 hours (tactical relevance window)

### Phase 2: UK Tactical Analysis

**Context**: UK battalion receives Polish data, analyzes with their own intelligence, and produces tactical recommendation.

**Action**: UK shares analysis back to Polish and US units.

**Constraints**:
- Still no strategic network connectivity
- Must work with locally cached credentials/certificates
- Time-critical (enemy movement imminent)

**Data Classification**: UK Secret (S)

**Access Requirements**:
- UK personnel with S clearance
- Polish personnel with NS clearance (data originated from Polish sources)
- US personnel with IL-5 clearance

### Phase 3: US Operational Orders

**Context**: US unit receives Polish reconnaissance and UK analysis, issues coordinated operational orders.

**Action**: US shares operational orders with Polish and UK units.

**Constraints**:
- Partial connectivity restored (low bandwidth)
- Orders must be distributed quickly (< 15 minutes)
- Must work if connectivity drops again

**Data Classification**: IL-5

**Access Requirements**:
- US personnel with IL-5 clearance
- Polish personnel with NS clearance
- UK personnel with S clearance

### Phase 4: Connectivity Restoration

**Context**: After 12 hours, all units regain connectivity to strategic networks.

**Action**: Tactical data must be transitioned to strategic systems for:
- Long-term intelligence analysis
- Audit and compliance review
- Sharing with higher headquarters and other coalition partners

**Requirements**:
- Tactical data re-encrypted for strategic distribution
- Audit trails from tactical phase preserved
- Access policies updated for strategic audience

## Operational Constraints

1. **Connectivity**: Intermittent or no connectivity to strategic infrastructure
2. **Latency**: Time-critical tactical decisions (rapid response required)
3. **Bandwidth**: Limited (tactical radio networks, low-bandwidth satellite)
4. **Offline Duration**: Extended periods without strategic network access
5. **Equipment**: Ruggedized tactical systems with limited compute/storage
6. **Mobility**: Units are mobile and may change locations
7. **Certificate Validity**: Pre-distributed credentials must work offline
8. **Revocation**: Cannot check real-time certificate revocation status

## Technical Challenges

1. **Offline Encryption**: How to encrypt data without access to key management infrastructure?
2. **Offline Decryption**: How to decrypt and verify data without online policy checks?
3. **Certificate Validation**: How to validate certificates without OCSP/CRL connectivity?
4. **Key Pre-Distribution**: How to distribute keys/certificates before deployment?
5. **Credential Staleness**: How to handle potentially stale revocation information?
6. **Tactical-to-Strategic Transition**: How to move data from tactical to strategic systems?
7. **Bandwidth Efficiency**: How to minimize data size for low-bandwidth links?
8. **Audit in Disconnected Mode**: How to log access when audit servers unreachable?

## Acceptance Criteria

### AC1: Offline Encryption
- [ ] Polish unit can encrypt reconnaissance data without connectivity to PL-KAS
- [ ] Encryption process completes quickly for typical tactical datasets
- [ ] Encrypted data includes access policies for UK and US units

### AC2: Offline Decryption
- [ ] UK unit can decrypt Polish data without connectivity to PL-KAS
- [ ] US unit can decrypt Polish data without connectivity to PL-KAS
- [ ] Decryption works using pre-distributed credentials only
- [ ] Access policy enforced locally (no online policy check required)

### AC3: Certificate Pre-Distribution
- [ ] Units receive certificates/keys during mission planning (before deployment)
- [ ] Certificates valid for mission duration
- [ ] Certificate bundle size is small enough for tactical systems

### AC4: Offline Certificate Validation
- [ ] Units can validate certificates using pre-distributed CRL
- [ ] CRL staleness acceptable for tactical mission duration
- [ ] Validation process completes quickly
- [ ] Clear indication when CRL is stale (warning, not failure)

### AC5: Bandwidth Efficiency
- [ ] Encrypted data overhead is minimal
- [ ] Certificate/policy metadata is small
- [ ] Suitable for transmission over tactical radio networks (low bandwidth)

### AC6: Rapid Distribution
- [ ] Data encrypted and ready for transmission quickly
- [ ] Recipient can decrypt and access quickly
- [ ] End-to-end sharing time is fast enough for tactical operations

### AC7: Local Audit Logging
- [ ] All encryption/decryption events logged locally
- [ ] Logs include: timestamp, user, data identifier, action
- [ ] Logs stored securely on tactical device
- [ ] Logs synchronized to strategic audit system when connectivity restored

### AC8: Tactical-to-Strategic Transition
- [ ] Tactical data can be re-encrypted for strategic distribution
- [ ] Transition process preserves audit trail from tactical phase
- [ ] Access policies can be updated for strategic audience
- [ ] Process works for data created by any of the three nations

### AC9: Graceful Degradation
- [ ] System works with zero connectivity (fully offline)
- [ ] System works with intermittent connectivity (opportunistic sync)
- [ ] System works with low bandwidth connections
- [ ] Clear user feedback about connectivity status and limitations

### AC10: Emergency Revocation
- [ ] Compromised certificates can be revoked via out-of-band channel (radio message)
- [ ] Units can manually add certificates to local revocation list
- [ ] Revocation effective immediately on local unit
- [ ] Revocation synchronized to other units when connectivity available

## Success Metrics

- **Offline Duration**: Support extended periods without strategic connectivity
- **Encryption Time**: Fast encryption for typical tactical datasets
- **Decryption Time**: Fast decryption for typical tactical datasets
- **Distribution Time**: Fast end-to-end sharing (including transmission)
- **Certificate Validation**: Fast offline validation
- **Bandwidth Overhead**: Minimal metadata overhead
- **Audit Completeness**: All events logged (synchronized when online)

## Out of Scope

- Strategic intelligence sharing with full connectivity (covered in Scenario 01)
- Real-time voice/video communications
- Streaming sensor data
- Multi-hop routing through tactical networks
- Mesh network key distribution
- Post-quantum cryptography (future consideration)

## Transition to Scenario 01

When tactical units regain strategic connectivity:
- Tactical data transitions to strategic systems
- Tactical encryption (PKI-based) converted to strategic encryption (TDF-based)
- Access policies expanded for strategic audience
- Audit trails merged into strategic audit systems

This transition is the bridge between Scenario 02 (tactical) and Scenario 01 (strategic).

---

*This scenario focuses on tactical edge operations with DDIL connectivity. For strategic sharing with reliable connectivity, see Scenario 01.*
