# Scenario 10: Multi-Domain Sensor-to-Shooter Data Chain

## Overview

Modern warfare demands that sensor data reaches decision-makers and weapon systems in seconds, not minutes. The kill chain -- from sensor detection through processing, exploitation, dissemination, decision, and action -- crosses multiple classification domains, national boundaries, and operational tiers. Current manual security review processes cannot keep pace with operational tempo. This scenario explores how data-centric security can enable secure, low-latency data flow across the entire kill chain with automated, policy-based access decisions.

## Problem Statement

The fundamental tension in the sensor-to-shooter chain is speed versus security. Ukraine's GIS Arta system demonstrated that software-defined kill chains can reduce sensor-to-shooter time from 20+ minutes to under 1 minute -- but that was within a single national security domain. Coalition operations add classification boundaries, release authority processes, and cross-domain transfer requirements at every stage. Current human-in-the-loop security review creates unacceptable latency for time-sensitive targeting. Pre-positioned ABAC policies enforced at the data object level could enable automated, policy-driven security decisions at machine speed.

## Actors

### Sensors (Multiple Nations)
- **ISR Aircraft**: NATO JISR assets (e.g., RQ-4D Phoenix), national reconnaissance
- **Ground Sensors**: Radar, SIGINT collectors, forward observers
- **Space Assets**: Satellite imagery, signals collection
- **Maritime Sensors**: Ship-based radar, sonar, maritime patrol aircraft
- **Cyber/SIGINT**: Electronic intelligence, communications intercepts

### Processing Nodes
- **Tactical Processing**: Edge compute at battalion/brigade level
- **Theatre Processing**: NATO JISR Federated PED (FEDPED) nodes
- **National Processing**: National intelligence centres
- **Role**: Correlate, fuse, and exploit raw sensor data into actionable intelligence

### Decision Authorities
- **Targeting Officers**: Authorise engagement of specific targets
- **Commanders**: Approve rules of engagement, weapon release authority
- **Legal Advisors**: Confirm compliance with laws of armed conflict
- **Role**: Make time-critical decisions based on fused intelligence

### Effectors
- **Strike Aircraft**: Close air support, strategic strike
- **Artillery/Fires**: Ground-based fire support
- **Naval Weapons**: Ship-based missile systems
- **Role**: Engage targets based on authorised targeting data

## Scenario Flow

### Phase 1: Sensor Detection

**Context**: NATO JISR RQ-4D Phoenix detects mobile surface-to-air missile system moving to a new firing position. Detection is time-critical -- once emplaced, the SAM threatens coalition aircraft.

**Sensor Data**:
- Raw radar imagery showing vehicle movement
- Classification: NATO SECRET (detection fact), TOP SECRET (sensor capabilities)
- Time sensitivity: Target must be engaged within 15 minutes before emplacement

**DCS Challenge**: Raw sensor data reveals collection capabilities (resolution, coverage area). Processed target location does not. The kill chain needs the target location at SECRET; the raw imagery must stay at TOP SECRET.

### Phase 2: Edge Processing

**Context**: Sensor data arrives at a FEDPED processing node. AI/ML algorithms identify the target type and generate a target nomination.

**Processed Output**:
```
Target: Mobile SAM system (SA-21 assessed)
Location: GRID 12345678
Confidence: HIGH (corroborated by SIGINT)
Time Sensitivity: IMMEDIATE (emplacement in 15 minutes)
Classification: NATO SECRET (target nomination)
Source Classification: TOP SECRET (raw sensor data)
Releasability: Coalition strike assets
```

**DCS Challenge**: The processed target nomination is at a lower classification than the raw sensor data. The system must automatically downgrade the output while protecting the input. This is "write-down by design" -- the processing pipeline is pre-accredited to produce lower-classification outputs from higher-classification inputs.

### Phase 3: Target Validation and Legal Review

**Context**: Targeting officer and legal advisor must validate the target before weapons release is authorised.

**Requirements**:
- Targeting officer sees target nomination with supporting intelligence
- Legal advisor confirms no protected sites (hospitals, cultural property) in engagement zone
- Commander provides weapons release authority
- All decisions logged for post-strike accountability

**DCS Challenge**: The validation chain must complete in minutes, not hours. Pre-positioned ABAC policies must enable automated routing to authorised personnel without manual release authority decisions. Each person in the chain sees only what they need: the commander sees the recommendation; the legal advisor sees the collateral damage estimate; the targeting officer sees the full intelligence picture.

### Phase 4: Weapons Engagement

**Context**: Strike authorised. Targeting data must reach the effector (strike aircraft, artillery battery, or naval vessel) with guaranteed integrity.

**Targeting Data to Effector**:
```
Target: Mobile SAM system
Location: GRID 12345678 (verified)
Engagement Window: 12 minutes remaining
Weapon Guidance: [COORDINATES]
Restrictions: Minimum standoff distance, avoid civilian structures within 200m
Classification: SECRET
Releasability: Assigned strike asset (UK Typhoon flight)
Integrity: Cryptographically signed -- coordinates verified
```

**DCS Challenge**: Targeting data integrity is life-or-death. Wrong coordinates cause friendly fire or civilian casualties. The data must be cryptographically signed to prevent tampering, and the effector must be able to verify the signature even in degraded connectivity.

### Phase 5: Battle Damage Assessment

**Context**: Post-strike, sensor data confirms target destruction. Assessment feeds back into the intelligence cycle.

**BDA Data**:
- Post-strike imagery confirming target destroyed
- Classification varies: strike result (SECRET), sensor imagery (TOP SECRET)
- Must reach targeting cell, higher headquarters, and lessons learned
- Attribution: which sensor, which processor, which authoriser, which effector

**DCS Challenge**: Complete audit trail from detection through engagement to assessment. Every data object in the chain must be traceable for legal accountability and lessons learned.

## Operational Constraints

1. **Latency**: End-to-end kill chain must complete in minutes for time-sensitive targets
2. **Multi-Level Classification**: Data changes classification at each stage of the chain
3. **Multi-National**: Sensors, processors, decision-makers, and effectors may be from different nations
4. **Integrity**: Targeting data tampering has catastrophic consequences
5. **Accountability**: Every decision in the chain must be auditable for legal compliance
6. **Automated Decisions**: Security policy must be enforced at machine speed, not human speed
7. **DDIL Resilience**: Kill chain must function with degraded connectivity between nodes

## Technical Challenges

1. **Automated Classification Downgrade**: How to pre-accredit processing pipelines to produce lower-classification outputs from higher-classification inputs?
2. **Policy Pre-positioning**: How to distribute ABAC policies to all nodes before operations begin?
3. **Latency vs. Encryption**: How to minimise crypto overhead in a time-critical chain?
4. **Integrity Verification**: How to verify data integrity at each handoff without adding latency?
5. **Cross-National Kill Chain**: How to enable a kill chain that spans nations (sensor from Nation A, processor from Nation B, effector from Nation C)?
6. **Audit at Speed**: How to log every transaction without impacting real-time performance?
7. **Graceful Degradation**: What happens when connectivity to KAS is lost mid-kill chain?

## Acceptance Criteria

### AC1: Automated Classification Management
- [ ] Processing pipelines produce outputs at appropriate classification levels
- [ ] Raw sensor data protected at higher classification than processed outputs
- [ ] Classification decisions based on pre-approved processing accreditation
- [ ] No human-in-the-loop required for routine classification downgrade
- [ ] Exceptional cases flagged for human review

### AC2: Policy-Driven Routing
- [ ] Target nominations automatically routed to authorised targeting officers
- [ ] Routing based on pre-positioned ABAC policies (role, clearance, mission assignment)
- [ ] No manual release authority decision for pre-approved data types
- [ ] Policies distributed to all nodes before operations begin
- [ ] Policy updates propagate across the kill chain in near real-time

### AC3: Kill Chain Latency
- [ ] Sensor-to-effector data flow completes within operational time constraints
- [ ] Security controls add minimal latency at each stage
- [ ] Encryption/decryption overhead acceptable for time-critical operations
- [ ] Parallel policy evaluation where possible (not sequential gate checks)

### AC4: Data Integrity
- [ ] Targeting data cryptographically signed at each stage
- [ ] Effector can verify integrity of targeting coordinates
- [ ] Tampering detected and flagged before weapon release
- [ ] Signature verification works in degraded connectivity
- [ ] Chain of custody traceable from sensor to effector

### AC5: Cross-National Kill Chain
- [ ] Sensor data from Nation A reaches effector from Nation B via pre-approved policies
- [ ] Each nation's KAS enforces national policies on their contributed data
- [ ] Federated key management supports multi-national kill chains
- [ ] No single nation has unilateral control over another nation's data
- [ ] National caveats enforced throughout the chain

### AC6: Comprehensive Audit Trail
- [ ] Every data handoff logged with timestamp, source, destination, policy decision
- [ ] Targeting decisions traceable for legal accountability
- [ ] Audit data collected even in degraded connectivity (cached locally, synced later)
- [ ] Audit trail supports post-strike legal review and lessons learned
- [ ] Tamper-evident audit logs

### AC7: DDIL Resilience
- [ ] Kill chain functions with degraded connectivity between nodes
- [ ] Pre-cached policies and keys enable local security decisions
- [ ] Graceful degradation: kill chain narrows (fewer targets, fewer effectors) rather than fails
- [ ] Connectivity restoration triggers audit synchronisation

### AC8: Role-Based Visibility
- [ ] Sensor operators see raw sensor data
- [ ] Processing nodes see raw data and produce processed outputs
- [ ] Targeting officers see target nominations with supporting intelligence
- [ ] Legal advisors see collateral damage estimates and protected site data
- [ ] Effectors see targeting data (coordinates, weapon guidance, restrictions)
- [ ] Each role sees only what they need for their function

## Success Metrics

- **Kill Chain Speed**: Sensor-to-effector within operational time constraints
- **Security Overhead**: Minimal latency added by DCS at each stage
- **Integrity**: No targeting data corruption across the chain
- **Audit Completeness**: Every transaction logged and traceable
- **Cross-National**: Kill chain works across multiple nations' systems
- **Accountability**: Post-strike review can reconstruct entire decision chain

## Example Use Cases

### Use Case 1: Time-Sensitive Target (Air)
**Sensor**: NATO JISR aircraft detects mobile SAM
**Processing**: FEDPED node produces target nomination
**Decision**: Targeting officer and legal advisor approve in minutes
**Effector**: UK Typhoon engages with precision munition
**Audit**: Full chain traceable for post-strike review

### Use Case 2: Counter-Battery Fire (Land)
**Sensor**: Counter-battery radar detects enemy artillery firing
**Processing**: Edge compute at brigade HQ generates firing solution
**Decision**: Pre-authorised rules of engagement (no human delay for counter-battery)
**Effector**: Allied artillery battery responds
**Audit**: Automated logging of pre-authorised engagement

### Use Case 3: Anti-Ship Missile Defence (Maritime)
**Sensor**: Ship radar detects incoming anti-ship missile
**Processing**: Combat management system classifies threat
**Decision**: Automated (self-defence, pre-authorised)
**Effector**: Ship's close-in weapon system engages
**Audit**: All sensor data and engagement decisions logged

## Out of Scope

- Weapon system integration (separate programme)
- Tactical data link protocols (Link 16, etc.)
- Rules of engagement definition (legal/policy matter)
- AI/ML model development for target recognition
- Network architecture and communications infrastructure

## Related Scenarios

- **Scenario 02**: Tactical DDIL -- kill chain must work in degraded connectivity
- **Scenario 04**: Cross-domain sanitisation -- automated downgrade in the processing pipeline
- **Scenario 07**: Coalition air operations -- airspace coordination alongside kill chain

## Key Assumptions

1. **Pre-Approved Policies**: Nations agree policies for common target types before operations
2. **Processing Accreditation**: FEDPED nodes pre-accredited for classification downgrade
3. **Latency Tolerance**: Some security overhead acceptable if within operational time constraints
4. **Legal Framework**: Rules of engagement defined and encoded as ABAC policies
5. **Trust in Automation**: Nations accept automated security decisions for time-sensitive operations

## Risk Considerations

**Security Risks**:
- Automated security decisions bypass human judgment
- Pre-positioned policies may not cover novel situations
- Compromised processing node could inject false targeting data
- Audit logs reveal operational patterns and capabilities

**Operational Risks**:
- Over-restrictive policies prevent time-sensitive engagement
- Security latency causes target to escape
- Integrity verification failure prevents weapon release
- Cross-national policy conflicts block kill chain

**Mitigation Strategies**:
- Human override capability for exceptional cases
- Regular policy review and update cycles
- Cryptographic integrity verification at every handoff
- Fallback to voice-authorised targeting when automated chain fails
- Regular exercises to test cross-national kill chains

---
