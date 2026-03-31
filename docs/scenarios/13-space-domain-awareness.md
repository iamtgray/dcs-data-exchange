# Scenario 13: Space Domain Awareness Data Sharing

## Overview

NATO declared space its fifth operational domain in 2019 and is investing over $1 billion in the Alliance Persistent Surveillance from Space (APSS) programme, creating "Aquila" -- a virtual constellation of national and commercial surveillance satellites from 17+ contributing nations. The NATO Space Operations Centre (NSpOC) at Ramstein became operational in 2024. Space domain awareness requires fusing data from highly classified national reconnaissance satellites, military space situational awareness sensors, and commercial satellite imagery into a common picture. The challenge is enabling effective space domain awareness while protecting the most sensitive national space capabilities.

## Problem Statement

Space-based assets are among the most classified capabilities of any nation. Satellite resolution, orbital parameters, and sensor characteristics reveal collection capabilities that nations guard closely. Yet effective alliance defence requires sharing the products of these assets -- imagery, signals intelligence, orbital tracking, and space weather data -- with coalition partners. Additionally, commercial satellite imagery is increasingly operationally relevant and must be fused with classified national assets. The APSS "virtual constellation" model means 17+ nations contribute sensors but retain sovereignty over their assets. This requires a federated data sharing architecture where each nation controls access to their contributed data while enabling an alliance-wide space picture.

## Actors

### Contributing Nations (17+ APSS participants)
- **Contributions**: National satellite imagery, radar, signals collection, space tracking
- **Classification**: Ranges from UNCLASSIFIED (commercial) to TOP SECRET (national reconnaissance)
- **Controls**: Each nation retains sovereignty over their space asset data
- **Constraint**: Satellite capabilities must not be revealed through shared products

### Commercial Satellite Providers
- **Contributions**: Optical imagery, synthetic aperture radar (SAR), AIS from space
- **Classification**: UNCLASSIFIED (commercial products)
- **Constraint**: Commercial terms of service, licensing restrictions on redistribution

### NATO Space Operations Centre (NSpOC)
- **Location**: Ramstein, Germany
- **Role**: Focal point for space support to NATO operations
- **Capabilities**: Space domain awareness, space weather, satellite communications coordination

### Strategic Space Situational Awareness System (3SAS)
- **Established**: June 2021
- **Role**: Track objects in orbit, detect threats to allied space assets
- **Data**: Orbital parameters, conjunction assessments, space debris tracking

### Intelligence Consumers
- **Military Commanders**: Need satellite-derived intelligence for operations
- **Targeting Officers**: Need precision geolocation from satellite imagery
- **Maritime Watch Officers**: Need satellite-based maritime surveillance
- **Clearances**: Range from SECRET to TOP SECRET depending on role

## Scenario Flow

### Phase 1: Commercial Satellite Imagery Integration

**Context**: Commercial satellite provider captures imagery of port facility used by adversary naval forces.

**Commercial Data**:
```
Source: Commercial SAR satellite (Planet, Maxar, or similar)
Product: 1m resolution SAR imagery
Location: Adversary naval base
Date: Current
Classification: UNCLASSIFIED (commercial product)
Licensing: NATO procurement contract permits redistribution to allies
```

**DCS Application**: Commercial imagery wrapped in ZTDF with policy permitting access to all NATO nations plus partner nations covered by the procurement contract. Provenance metadata identifies the commercial source and licensing terms.

### Phase 2: National Satellite Imagery Contribution

**Context**: UK contributes high-resolution imagery of the same facility from a national reconnaissance satellite. The imagery reveals details not visible in commercial products.

**National Data**:
```
Source: UK national reconnaissance satellite
Product: [RESOLUTION REDACTED] imagery
Location: Adversary naval base
Date: Current (same target as commercial)
Classification: UK TOP SECRET
Releasability: UK EYES ONLY (raw imagery)
Derived Product: SECRET, REL TO FVEY (annotated assessment)
Capability Protection: Resolution, orbital parameters, revisit rate MUST NOT be revealed
```

**DCS Application**: Raw imagery wrapped in ZTDF with UK EYES ONLY policy. Annotated assessment (which reveals what was seen but not the capability that saw it) wrapped separately with FVEY releasability. Metadata deliberately does not include satellite identity or orbital parameters.

### Phase 3: Multi-Source Fusion at NSpOC

**Context**: NSpOC analysts fuse commercial and national imagery to produce an operational intelligence product.

**Fusion Process**:
1. Analyst accesses commercial imagery (UNCLASSIFIED) -- authorised for all NATO analysts
2. Analyst accesses UK derived product (SECRET/FVEY) -- authorised for FVEY-cleared NSpOC analysts
3. Analyst accesses French SAR imagery of same area (SECRET/REL TO NATO) -- authorised for NATO analysts
4. Analyst produces fused assessment

**Fused Product**:
```
NAVAL BASE ACTIVITY ASSESSMENT

Source: Multiple (commercial and allied national sensors)
Classification: NATO SECRET
Releasability: NATO nations
Content: Three warships identified at berth, one in pre-deployment preparation
Assessment: Probable deployment within 72 hours
Supporting Imagery: Commercial SAR (attached, UNCLASSIFIED)
Detailed Imagery: [NOT ATTACHED - available to FVEY-cleared analysts]
```

**DCS Behaviour**: The fused product carries its own ZTDF policy (NATO SECRET/REL TO NATO). It references but does not embed the higher-classification national imagery. FVEY-cleared analysts can follow the reference to access detailed imagery; others see only the commercial imagery and the assessment text.

### Phase 4: Space Situational Awareness (Orbital Tracking)

**Context**: 3SAS detects a new object in orbit that may be an adversary anti-satellite weapon.

**Orbital Data**:
```
Object: NEW-SAT-2026-042
Orbit: LEO, [PARAMETERS]
First Detection: US Space Surveillance Network
Classification of Detection: SECRET (US)
Classification of Assessment: NATO SECRET
Conjunction Risk: Potential threat to allied communications satellites
```

**Sharing Requirement**: All NATO nations need to know about the conjunction risk to protect their satellites. But the orbital parameters and detection method may reveal US space surveillance capabilities.

**DCS Application**:
- Conjunction warning (which satellites are at risk, when, recommended manoeuvre) -- NATO SECRET, all allies
- Orbital parameters of the new object -- SECRET, limited distribution
- Detection method and US sensor capabilities -- TOP SECRET, US EYES ONLY
- Each element wrapped separately with appropriate ABAC policies

### Phase 5: Time-Critical Space Event Response

**Context**: GPS jamming detected over operational area. Space weather or adversary action? Time-critical assessment needed.

**Data Sources**:
- US GPS monitoring stations detect signal anomalies
- UK SIGINT detects jamming emissions (reveals SIGINT collection capability)
- Commercial space weather data shows no solar activity
- Assessment: Deliberate adversary jamming

**Sharing Requirement**: All NATO forces in the affected area need to know GPS is unreliable. The evidence for deliberate jamming is classified.

**DCS Application**:
- GPS reliability warning -- UNCLASSIFIED, broadcast to all NATO forces
- Technical assessment of jamming characteristics -- SECRET, REL TO NATO
- SIGINT evidence of deliberate jamming -- TOP SECRET, UK/US EYES ONLY
- Each wrapped in ZTDF with appropriate time-limited policies (jamming may be temporary)

## Operational Constraints

1. **Capability Protection**: Satellite resolution, orbital parameters, and revisit rates must not be revealed
2. **Virtual Constellation**: 17+ nations contribute sensors but retain sovereignty
3. **Commercial Integration**: Commercial data fused with classified national data
4. **Time Sensitivity**: Some space events (conjunction warnings, jamming) require rapid sharing
5. **Multi-Level**: Same event produces data at multiple classification levels
6. **Attribution**: Consumers must know which nation provided which data (for confidence assessment)
7. **Licensing**: Commercial satellite imagery may have redistribution restrictions

## Technical Challenges

1. **Capability Inference**: How to prevent recipients from inferring satellite capabilities from shared products?
2. **Commercial-Classified Fusion**: How to combine UNCLASSIFIED commercial and TOP SECRET national data?
3. **Virtual Constellation Federation**: How to federate 17+ national space data contributions?
4. **Time-Critical Sharing**: How to share conjunction warnings and jamming alerts rapidly?
5. **Geospatial Data Protection**: How to share location-based products without revealing collection geometry?
6. **Licensing Enforcement**: How to enforce commercial redistribution terms alongside military classification?

## Acceptance Criteria

### AC1: Capability Protection
- [ ] Satellite resolution not inferable from shared products
- [ ] Orbital parameters not revealed to unauthorised recipients
- [ ] Collection geometry not derivable from product metadata
- [ ] Sensor identity protected (products attributed to "national source" not specific satellite)

### AC2: Virtual Constellation Sharing
- [ ] Each contributing nation controls access to their data
- [ ] Nations can contribute at different classification levels
- [ ] Fused products respect all contributing nations' caveats
- [ ] No central authority required -- federated KAS per nation

### AC3: Commercial-Military Fusion
- [ ] Commercial imagery accessible to all authorised NATO personnel
- [ ] Commercial and classified imagery can be viewed together by authorised analysts
- [ ] Commercial licensing terms enforced alongside military classification
- [ ] Commercial data provenance tracked

### AC4: Multi-Level Product Generation
- [ ] Same event produces products at multiple classification levels
- [ ] Each level wrapped with appropriate ABAC policies
- [ ] Higher-level products reference (not embed) lower-level details
- [ ] Consumers see products appropriate to their authorisation

### AC5: Time-Critical Alerts
- [ ] Conjunction warnings distributed to all affected nations rapidly
- [ ] Jamming alerts reach affected forces rapidly
- [ ] Time-critical sharing uses pre-authorised policies (no human delay)
- [ ] Alert distribution logged for audit

### AC6: Comprehensive Audit Trail
- [ ] All data contributions logged with source nation
- [ ] All access to contributed data logged
- [ ] Fusion operations logged (which inputs produced which outputs)
- [ ] Time-critical alert distribution logged

## Success Metrics

- **Capability Protection**: No satellite capabilities revealed through shared products
- **Fusion Effectiveness**: Analysts can produce comprehensive assessments from multi-source data
- **Sharing Speed**: Time-critical alerts distributed within minutes
- **Audit Completeness**: All contributions, access, and fusion operations logged
- **Federation**: 17+ national contributions managed without central authority

## Out of Scope

- Satellite operations and tasking
- Space weapon systems
- Satellite communications management
- Space debris mitigation (except as it relates to data sharing)

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing -- space data is a form of strategic intelligence
- **Scenario 06**: Intelligence fusion -- space data fused with other intelligence sources
- **Scenario 08**: Maritime domain awareness -- satellite-based maritime surveillance

---
