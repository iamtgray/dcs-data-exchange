# Scenario 15: Counter-Hybrid Threat Intelligence and Disinformation Response

## Overview

NATO faces escalating hybrid threats combining cyber attacks, disinformation campaigns, economic coercion, and sabotage of critical infrastructure. Countering these threats requires fusing open-source intelligence (social media, news, public records), classified intelligence, private sector threat data, and civilian infrastructure status into a unified assessment. This is fundamentally different from traditional military intelligence sharing: it involves civilian agencies and EU partners who lack military clearances, evidence chains that may be used in legal or diplomatic contexts, and civil-military data fusion at unprecedented scale.

## Problem Statement

Hybrid threats exploit the seams between military and civilian domains, between national and alliance responsibilities, and between classified and unclassified information spaces. A disinformation campaign targeting a NATO nation may be detected by social media monitoring (UNCLASSIFIED), attributed by signals intelligence (TOP SECRET), corroborated by human intelligence (COMPARTMENTED), and countered by public diplomacy (UNCLASSIFIED). Current information sharing mechanisms cannot efficiently combine these classification levels, share assessments with civilian partners who lack clearances, or maintain evidence chains suitable for legal/diplomatic use. NATO's appointment of a Special Coordinator for Hybrid Threats (2025) and the European Centre for Countering Hybrid Threats in Helsinki demonstrate the urgency of this problem.

## Actors

### National Intelligence Services
- **Role**: Detect and attribute hybrid threats using classified capabilities
- **Contributions**: SIGINT attribution, HUMINT source reporting, cyber forensics
- **Classification**: SECRET to TOP SECRET/COMPARTMENTED
- **Constraint**: Sources and methods must be protected absolutely

### NATO Joint Intelligence and Security Division
- **Role**: Alliance-level hybrid threat assessment
- **Capabilities**: Hybrid analysis branch, counter-intelligence
- **Constraint**: Must produce assessments shareable with all 32 allies

### European Centre for Countering Hybrid Threats (Hybrid CoE)
- **Location**: Helsinki, Finland
- **Membership**: 32 countries (NATO + EU overlap)
- **Role**: Research, training, and exercises on hybrid threats
- **Constraint**: Non-classified environment; cannot access national intelligence directly

### National Civilian Agencies
- **Types**: Interior ministries, election commissions, telecom regulators, energy regulators
- **Clearances**: Generally none; some may hold limited national clearances
- **Role**: Implement countermeasures in civilian domain
- **Need**: Threat warnings and defensive guidance without classified sourcing

### Private Sector
- **Types**: Social media platforms, telecom providers, energy companies, banks
- **Clearances**: None
- **Role**: Detect anomalies in their platforms/infrastructure, implement mitigations
- **Need**: Indicators of targeting and recommended defensive actions

## Scenario Flow

### Phase 1: Hybrid Threat Detection

**Context**: Multiple indicators suggest a coordinated hybrid campaign targeting a NATO nation's upcoming election.

**Indicators from Multiple Sources**:

**OSINT (UNCLASSIFIED)**:
```
- Social media monitoring detects coordinated inauthentic behaviour
- 500+ bot accounts amplifying divisive narratives
- Deepfake video of political candidate circulating
- Narratives align with adversary state media talking points
Source: Open source monitoring tools
Classification: UNCLASSIFIED
```

**Cyber Intelligence (SECRET)**:
```
- Phishing campaigns targeting election infrastructure staff
- Malware samples consistent with [STATE ACTOR] toolkit
- Infrastructure overlaps with previous campaigns
Source: National CERT + military cyber defence
Classification: SECRET
Releasability: NATO
```

**SIGINT Attribution (TOP SECRET//SI)**:
```
- Intercepted communications confirm state direction
- Specific unit identified as coordinating the campaign
- Timeline and objectives assessed
Source: National SIGINT agency
Classification: TOP SECRET//SI
Releasability: FVEY initially
```

**DCS Application**: Each intelligence stream wrapped in ZTDF at appropriate classification. Cross-referencing enabled for authorised analysts without exposing higher-classification sourcing to lower-cleared consumers.

### Phase 2: Fused Hybrid Threat Assessment

**Context**: Analysts must produce assessments at multiple classification levels for different audiences.

**Assessment Products**:

**Product A -- Full Assessment (TOP SECRET)**:
```
Audience: National security council, alliance senior leadership
Content: Full attribution, sources and methods, adversary objectives
Classification: TOP SECRET
Releasability: FVEY, then selectively to NATO
```

**Product B -- Attribution Assessment (SECRET)**:
```
Audience: NATO allies, government ministries
Content: Attributed to [STATE ACTOR], TTPs described, objectives assessed
Classification: SECRET (no sources/methods)
Releasability: NATO nations
```

**Product C -- Threat Warning (RESTRICTED/UNCLASSIFIED)**:
```
Audience: Civilian agencies, election commissions, private sector
Content: Threat indicators, defensive recommendations, no attribution
Classification: NATO RESTRICTED or UNCLASSIFIED
Releasability: Government agencies + critical infrastructure operators
```

**DCS Application**: Each product wrapped in ZTDF with appropriate ABAC policies. Products reference each other (C references B, B references A) but higher-classification content is not embedded in lower-classification products.

### Phase 3: Civilian Partner Sharing

**Context**: Election commission needs to know their infrastructure is targeted. Telecom providers need to block malicious domains. Social media platforms need to remove coordinated inauthentic behaviour.

**Sharing with Civilians**:
- Election commission receives threat warning + specific phishing indicators
- Telecom providers receive malicious domain list for blocking
- Social media platforms receive bot account indicators for removal
- All receive defensive recommendations

**DCS Challenge**: These partners have no military clearances. They need actionable intelligence stripped of all classified context. But the unclassified indicators must still carry DCS protection to maintain provenance, prevent tampering, and enable audit.

**DCS Application**: ZTDF wrapping at UNCLASSIFIED/RESTRICTED level with ABAC policies restricting access to specific named civilian organisations. Audit trail tracks which organisations received which indicators and when they acted on them.

### Phase 4: Evidence Preservation for Legal/Diplomatic Use

**Context**: Nation may wish to publicly attribute the hybrid campaign or seek legal remedies.

**Evidence Requirements**:
- Tamper-evident chain of custody from detection through analysis to assessment
- Ability to declassify selected evidence for public attribution
- Legal admissibility: evidence integrity verifiable by third parties
- Diplomatic use: evidence shareable with international organisations (UN, EU, OSCE)

**DCS Application**: ZTDF provides cryptographic integrity for the evidence chain. Declassification involves creating new ZTDF-wrapped products at lower classification derived from higher-classification originals, with the derivation relationship tracked.

### Phase 5: Coordinated Response

**Context**: NATO and affected nation coordinate response across military, diplomatic, and civilian channels.

**Response Actions** (each generating data with different sharing requirements):
- Military: Increased cyber defence posture (SECRET)
- Diplomatic: Demarche to adversary state (CONFIDENTIAL)
- Public: Joint statement attributing campaign (UNCLASSIFIED)
- Technical: Defensive indicators distributed to allies (SECRET/UNCLASSIFIED)
- Legal: Evidence package for potential international proceedings (RESTRICTED)

**DCS Application**: Each response action generates data wrapped in ZTDF with policies appropriate to the action channel. Coordination across channels requires authorised personnel to access data from multiple response tracks.

## Operational Constraints

1. **Speed**: Hybrid campaigns evolve in hours; response must match
2. **Civil-Military Fusion**: Military intelligence must inform civilian defence without revealing sources
3. **Legal Admissibility**: Evidence must be tamper-evident for potential legal proceedings
4. **Non-Cleared Partners**: Civilian agencies and private sector lack military clearances
5. **Multi-Level Products**: Same threat requires assessments at multiple classification levels
6. **International Coordination**: NATO, EU, and national responses must be coordinated
7. **Public Attribution**: Selected evidence must be declassifiable for public statements

## Technical Challenges

1. **Civil-Military Data Boundary**: How to share with non-cleared partners while protecting sources?
2. **Evidence Integrity**: How to maintain tamper-evident chains suitable for legal proceedings?
3. **Declassification Workflow**: How to produce lower-classification products from higher-classification intelligence?
4. **Cross-Organisation Access**: How to authorise civilian agencies in military ABAC systems?
5. **OSINT Integration**: How to wrap UNCLASSIFIED OSINT in DCS alongside classified intelligence?
6. **Speed of Response**: How to produce multi-level assessments faster than the hybrid campaign evolves?

## Acceptance Criteria

### AC1: Multi-Level Assessment Production
- [ ] Same threat produces assessments at multiple classification levels
- [ ] Each level wrapped with appropriate ABAC policies
- [ ] Higher-level assessments reference (not embed) sensitive sourcing
- [ ] Assessment production faster than hybrid campaign evolution

### AC2: Civilian Partner Sharing
- [ ] Non-cleared civilian agencies receive actionable threat warnings
- [ ] Private sector receives relevant indicators for defence
- [ ] No classified content exposed to non-cleared partners
- [ ] Civilian access governed by ABAC policies (organisation, role, purpose)

### AC3: Evidence Integrity
- [ ] Tamper-evident chain from detection through assessment
- [ ] Evidence integrity verifiable by third parties
- [ ] Declassification workflow produces new ZTDF-wrapped products
- [ ] Derivation relationships tracked between classification levels

### AC4: Source Protection
- [ ] SIGINT and HUMINT sources never exposed in lower-classification products
- [ ] Attribution intelligence controlled by originator nation
- [ ] Civilian partners receive assessments without access to underlying intelligence
- [ ] Technical indicators shared without revealing collection method

### AC5: Cross-Organisation Coordination
- [ ] Military, diplomatic, public, and legal response tracks coordinated
- [ ] Authorised personnel access data across response tracks
- [ ] Each response track generates appropriately classified data
- [ ] Coordination logged for post-event review

### AC6: Comprehensive Audit Trail
- [ ] All intelligence contributions logged
- [ ] All assessment production steps logged
- [ ] All civilian sharing logged (who received what, when)
- [ ] All response actions logged
- [ ] Audit supports post-event review and lessons learned

## Success Metrics

- **Response Speed**: Multi-level assessments produced within hours of detection
- **Civilian Reach**: All relevant civilian partners receive actionable intelligence
- **Source Protection**: No classified sources revealed to non-cleared partners
- **Evidence Integrity**: Tamper-evident chains maintained throughout
- **Coordination**: Cross-channel response coordinated effectively

## Out of Scope

- Offensive cyber operations against hybrid threat actors
- Public diplomacy and strategic communications content
- Social media platform moderation policies
- Election security technology (voting machines, etc.)

## Related Scenarios

- **Scenario 04**: Cross-domain sanitisation -- producing lower-classification assessments
- **Scenario 06**: Intelligence fusion -- fusing multi-source intelligence
- **Scenario 12**: Cyber threat intelligence -- cyber component of hybrid threats

---
