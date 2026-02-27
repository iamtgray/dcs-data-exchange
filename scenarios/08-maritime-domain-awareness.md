# Scenario 08: Maritime Domain Awareness Data Sharing

## Overview

Maritime operations require sharing sensor data (radar tracks, AIS, sonar contacts) across multiple navies to create a common operational picture. Commercial shipping data should be shared broadly for safety and security, whilst military vessel data must be restricted based on classification and operational security. Submarine locations are highly sensitive and must be protected even from surface vessels in the same coalition. The challenge is fusing heterogeneous sensor data with different sharing policies whilst maintaining attribution and protecting sensitive capabilities.

## Problem Statement

Current maritime information sharing uses manual coordination and lowest-common-denominator data sharing. Commercial vessels are tracked openly, but military vessel data is often not shared even with coalition partners, creating gaps in the operational picture. Submarine operations require extreme operational security, but surface vessels need to know where submarines are operating to avoid interference. Automated sensor fusion with policy-based access control could improve maritime domain awareness whilst protecting sensitive operations.

## Actors

### Participating Navies (4-6 nations)
- **Surface Vessels**: Frigates, destroyers, aircraft carriers
- **Submarines**: Attack submarines, ballistic missile submarines
- **Maritime Patrol Aircraft**: P-8 Poseidon, P-3 Orion
- **Shore-Based Sensors**: Coastal radar, AIS receivers

### Commercial Shipping
- **Vessels**: Cargo ships, tankers, fishing vessels
- **Data**: AIS (Automatic Identification System) broadcasts
- **Sharing**: Openly shared for safety and security

### Maritime Operations Centre
- **Role**: Coordinate coalition maritime operations
- **Personnel**: Watch officers, intelligence analysts from multiple nations
- **Displays**: Common operational picture showing all vessels

### Sensor Types
- **Radar**: Surface search radar on ships and aircraft
- **AIS**: Automatic Identification System (commercial vessels)
- **Sonar**: Submarine detection (highly classified)
- **Satellite**: Overhead imagery and radar
- **ELINT**: Electronic intelligence (signals from vessels)

## Scenario Flow

### Phase 1: Commercial Shipping Tracking

**Context**: Coalition navies monitor commercial shipping in operational area for security and safety.

**AIS Data (UNCLASSIFIED - Widely Shared)**:
```
Vessel: MV NORTHERN STAR
Type: Container ship
Flag: Liberia
Position: 35.5°N, 15.2°E
Course: 045°
Speed: 18 knots
Destination: Malta
Classification: UNCLASSIFIED
Releasability: All coalition partners, commercial entities
Source: AIS broadcast (open source)
```

**Access Control**:
- ✅ All coalition navies see commercial shipping
- ✅ Commercial entities see commercial shipping
- ✅ Port authorities see commercial shipping
- ✅ Search and rescue services see commercial shipping

### Phase 2: Surface Warship Tracking

**Context**: Coalition surface vessels operating in same area need to coordinate movements.

**UK Frigate Track (SECRET - Coalition)**:
```
Vessel: HMS DEFENDER (Type 45 Destroyer)
Position: 35.8°N, 15.5°E
Course: 090°
Speed: 20 knots
Mission: Air defence
Classification: SECRET
Releasability: Coalition partners (UK, US, FR, IT)
Source: UK naval operations centre
Capabilities: [RESTRICTED] - Air defence radar range, weapons systems
```

**US Carrier Strike Group (SECRET - Selective)**:
```
Vessel: USS GEORGE H.W. BUSH (Aircraft Carrier)
Position: 36.0°N, 16.0°E
Course: 180°
Speed: 15 knots
Mission: Power projection
Classification: SECRET
Releasability: UK, US (close allies only)
Source: US naval operations centre
Capabilities: [RESTRICTED] - Aircraft operations, strike range
Strike Group Composition: [TOP SECRET] - Submarine escort details
```

**Access Control**:
- ✅ UK and US see both UK frigate and US carrier
- ✅ French and Italian navies see UK frigate
- ❌ French and Italian navies see US carrier position but not strike group composition
- ❌ Commercial entities cannot see military vessels

### Phase 3: Submarine Operations

**Context**: UK submarine operating in same area. Surface vessels must not interfere, but submarine location is highly classified.

**Submarine Operating Area (TOP SECRET - Highly Restricted)**:
```
Vessel: HMS ASTUTE (Attack Submarine)
Position: [REDACTED]
Depth: [REDACTED]
Mission: [REDACTED]
Classification: TOP SECRET
Releasability: UK EYES ONLY
Source: UK submarine operations centre
```

**Submarine Exclusion Zone (SECRET - Coalition Surface Vessels)**:
```
Area: SUBSURFACE OPERATIONS AREA ALPHA
Boundaries: 35.0°N to 36.0°N, 14.0°E to 16.0°E
Time: 0600Z to 1800Z
Classification: SECRET
Releasability: Coalition surface vessels
Restriction: No active sonar, no ASW (Anti-Submarine Warfare) operations
Purpose: Friendly submarine operations (details classified)
```

**Access Control**:
- ✅ Coalition surface vessels see exclusion zone (avoid interference)
- ❌ Coalition surface vessels do not see submarine position or mission
- ✅ UK submarine operations centre sees all surface vessels (deconfliction)
- ❌ US carrier strike group does not see UK submarine position
- ✅ UK national command sees submarine position and mission

### Phase 4: Sensor Fusion

**Context**: Multiple sensors detect unknown surface contact. Fusion required to identify and track.

**Sensor Reports**:

**UK Frigate Radar (SECRET)**:
```
Contact: UNKNOWN-001
Position: 35.3°N, 15.8°E
Course: 270°
Speed: 25 knots
Classification: SECRET
Source: HMS DEFENDER surface search radar
Confidence: High
```

**US Maritime Patrol Aircraft (SECRET)**:
```
Contact: UNKNOWN-001 (correlated)
Position: 35.3°N, 15.8°E
Course: 270°
Speed: 25 knots
Classification: SECRET
Source: P-8 Poseidon radar
Additional Data: No AIS broadcast (suspicious)
Confidence: High
```

**French Satellite (SECRET)**:
```
Contact: UNKNOWN-001 (correlated)
Position: 35.3°N, 15.8°E
Image: [ATTACHED]
Classification: SECRET
Source: French military satellite
Additional Data: Fast attack craft profile
Confidence: Medium
```

**Fused Track (SECRET - Coalition)**:
```
Contact: UNKNOWN-001 (FUSED)
Position: 35.3°N, 15.8°E
Course: 270°
Speed: 25 knots
Classification: SECRET
Releasability: Coalition partners
Sources: UK radar, US aircraft, FR satellite
Assessment: Likely hostile fast attack craft
Confidence: High
Recommendation: Intercept and identify
```

**Access Control**:
- ✅ All coalition navies see fused track
- ✅ Attribution preserved (which nation provided which sensor data)
- ❌ Sensor capabilities (radar range, satellite resolution) restricted
- ✅ Tactical recommendation shared with all coalition

### Phase 5: Dynamic Access Control

**Context**: US submarine joins operations. Needs to see surface vessels but must not be revealed to coalition partners.

**US Submarine Access**:
- ✅ US submarine sees all surface vessels (coalition and commercial)
- ✅ US submarine sees UK submarine exclusion zone (deconfliction)
- ❌ US submarine position not revealed to coalition partners
- ✅ US submarine operations centre sees all coalition vessels
- ❌ UK does not see US submarine position (national compartmentalisation)

**New Exclusion Zone (SECRET - Coalition Surface Vessels)**:
```
Area: SUBSURFACE OPERATIONS AREA BRAVO
Boundaries: 36.5°N to 37.5°N, 16.5°E to 18.5°E
Time: 1200Z to 2400Z
Classification: SECRET
Releasability: Coalition surface vessels
Restriction: No active sonar, no ASW operations
Purpose: Friendly submarine operations (details classified)
Note: US submarine operations (not revealed to coalition)
```

## Operational Constraints

1. **Real-Time Updates**: Vessel positions update every few minutes
2. **Sensor Fusion**: Correlate tracks from multiple sensors
3. **Attribution**: Maintain source of each sensor report
4. **Submarine Security**: Submarine positions highly classified
5. **Commercial Shipping**: Openly shared for safety
6. **Capability Protection**: Sensor capabilities (range, resolution) restricted
7. **Dynamic Access**: Vessels join/leave operations frequently
8. **Graceful Degradation**: System works if one nation's sensors unavailable

## Technical Challenges

1. **Real-Time Fusion**: How to correlate tracks from multiple sensors in real-time?
2. **Heterogeneous Data**: How to fuse radar, AIS, satellite, sonar data?
3. **Attribution Preservation**: How to maintain sensor source through fusion?
4. **Submarine Protection**: How to coordinate without revealing submarine positions?
5. **Dynamic Access Control**: How to handle vessels joining/leaving operations?
6. **Capability Protection**: How to share tracks without revealing sensor capabilities?
7. **Performance**: How to update common operational picture in real-time?
8. **Federation**: How to coordinate across multiple national maritime operations centres?

## Acceptance Criteria

### AC1: Commercial Shipping Visibility
- [ ] All commercial vessels visible to all coalition partners
- [ ] AIS data shared openly
- [ ] Commercial entities can access commercial shipping data
- [ ] Real-time updates (every few minutes)

### AC2: Surface Warship Coordination
- [ ] Coalition surface vessels visible to each other
- [ ] Vessel positions updated in real-time
- [ ] Mission types visible for coordination
- [ ] Capabilities restricted appropriately
- [ ] Deconfliction automatic

### AC3: Submarine Protection
- [ ] Submarine positions highly classified
- [ ] Submarine exclusion zones visible to surface vessels
- [ ] Surface vessels cannot determine submarine positions from exclusion zones
- [ ] Submarines see all surface vessels for deconfliction
- [ ] National compartmentalisation (UK submarine hidden from US, and vice versa)

### AC4: Sensor Fusion
- [ ] Tracks from multiple sensors correlated automatically
- [ ] Fused tracks show all contributing sensors
- [ ] Attribution preserved (which nation provided which sensor)
- [ ] Confidence levels indicated
- [ ] Sensor capabilities protected

### AC5: Dynamic Access Control
- [ ] Vessels joining operations gain appropriate access
- [ ] Vessels leaving operations lose access
- [ ] Access based on nationality, vessel type, and mission
- [ ] Real-time access updates
- [ ] No re-encryption required when access changes

### AC6: Multi-Level Classification
- [ ] Commercial shipping (UNCLASSIFIED)
- [ ] Surface warships (SECRET)
- [ ] Submarine operations (TOP SECRET)
- [ ] Sensor capabilities (TOP SECRET)
- [ ] Each user sees appropriate classification level

### AC7: Comprehensive Audit Trail
- [ ] All data access logged
- [ ] Sensor contributions tracked
- [ ] Fusion operations logged
- [ ] Access decisions logged
- [ ] Audit logs support security investigations

### AC8: Performance
- [ ] Real-time track updates (every few minutes)
- [ ] Sensor fusion completes quickly
- [ ] Access decisions with minimal latency
- [ ] Scales to hundreds of vessels
- [ ] Common operational picture updates in real-time

### AC9: Capability Protection
- [ ] Radar ranges not revealed
- [ ] Satellite resolution not revealed
- [ ] Sonar capabilities highly classified
- [ ] Tracks shared without revealing sensor capabilities
- [ ] Attribution shows sensor type but not detailed capabilities

### AC10: Federation
- [ ] Each nation operates independent maritime operations centre
- [ ] Coordination works if one nation's centre unavailable
- [ ] No central authority required
- [ ] Each nation maintains sovereignty over their data

## Success Metrics

- **Track Accuracy**: Fused tracks accurately represent vessel positions
- **Update Latency**: Real-time updates propagate quickly
- **Submarine Security**: Submarine positions never revealed to unauthorised personnel
- **Fusion Effectiveness**: Multiple sensor reports correctly correlated
- **Attribution Accuracy**: Sensor sources correctly identified
- **User Satisfaction**: Watch officers find common operational picture effective
- **Audit Completeness**: All access attempts logged

## Example Use Cases

### Use Case 1: Anti-Piracy Operations
**Commercial Shipping**: Openly tracked for protection
**Naval Vessels**: Coalition frigates visible to each other
**Suspicious Contacts**: Fused from multiple sensors, shared with all coalition
**Submarine**: Not involved, no submarine exclusion zones

### Use Case 2: Carrier Strike Group Operations
**US Carrier**: Position shared with close allies only
**Strike Group Composition**: Highly classified (includes submarine escort)
**Coalition Support**: Surface vessels coordinate with carrier
**Submarine Escort**: Position hidden even from coalition surface vessels

### Use Case 3: Submarine Operations
**UK Submarine**: Conducting intelligence collection
**Exclusion Zone**: Surface vessels notified to avoid interference
**Submarine Position**: Hidden from all coalition partners
**Surface Vessels**: Visible to submarine for deconfliction

## Out of Scope

- Tactical data links (Link 11, Link 22) - separate system
- Weapons systems coordination - separate system
- Underwater communications - separate system
- Long-term intelligence analysis - separate system

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing - long-term intelligence sharing
- **Scenario 06**: Intelligence fusion - sensor data fusion
- **Scenario 07**: Coalition air operations - airspace coordination

## Key Assumptions

1. **Real-Time Requirements**: Few-minute latency acceptable for vessel tracking
2. **Sensor Correlation**: Automated correlation of tracks from multiple sensors
3. **Trust Framework**: Nations trust maritime operations centre infrastructure
4. **Technical Capability**: Nations can integrate sensors with operations centre
5. **Submarine Security**: Submarine protection takes precedence over coordination

## Risk Considerations

**Security Risks**:
- Submarine positions revealed through exclusion zones or track correlation
- Sensor capabilities revealed through track accuracy
- Military vessel positions leaked to adversaries
- Audit logs reveal operational patterns

**Operational Risks**:
- Over-restrictive access controls create coordination gaps
- Sensor fusion errors create false tracks
- Real-time performance insufficient for safety
- Submarine exclusion zones interfere with surface operations

**Mitigation Strategies**:
- Large exclusion zones prevent submarine position determination
- Sensor capabilities abstracted in fused tracks
- Redundant sensors for critical areas
- Regular exercises to test coordination procedures
- Continuous monitoring and performance optimisation

---

*This scenario enables effective maritime domain awareness whilst protecting submarine operations and sensitive sensor capabilities. Automated sensor fusion with policy-based access control improves coordination without compromising security.*
