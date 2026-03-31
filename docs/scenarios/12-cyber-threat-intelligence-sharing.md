# Scenario 12: Coalition Cyber Threat Intelligence Sharing

## Overview

NATO nations face persistent cyber threats from state and non-state actors targeting military networks, critical infrastructure, and defence industrial bases. Effective defence requires rapid sharing of cyber threat intelligence (CTI) -- indicators of compromise, malware analysis, vulnerability data, and attribution assessments -- across national boundaries and between military and civilian partners. CTI is unique because it is consumed by machines (SIEMs, SOARs, firewalls) as much as by humans, operates at extremely high velocity, and spans the full classification spectrum from UNCLASSIFIED technical indicators to TOP SECRET attribution intelligence.

## Problem Statement

NATO operates the Malware Information Sharing Platform (MISP) for rapid indicator sharing and has established the Integrated Cyber Defence Centre (2024) at SHAPE. However, current sharing mechanisms struggle with the dual nature of CTI: defensive indicators (IP addresses, file hashes, domain names) should be shared as broadly and rapidly as possible, while offensive capabilities, collection methods, and attribution intelligence must be tightly controlled. The same malware sample may be UNCLASSIFIED as a file hash but TOP SECRET when paired with attribution analysis revealing the actor and collection method. Nations need to share defensive intelligence at machine speed while maintaining granular control over sensitive context.

## Actors

### National Cyber Defence Centres
- **Role**: Detect threats to national military and government networks
- **Capabilities**: SIGINT-derived threat data, malware analysis, intrusion detection
- **Contributions**: IOCs, TTPs, malware samples, vulnerability assessments
- **Controls**: Each nation specifies releasability for different CTI elements

### NATO Cyber Security Centre (NCSC)
- **Role**: Protect NATO enterprise networks, coordinate alliance-wide defence
- **Capabilities**: Network monitoring, incident response, threat analysis
- **Infrastructure**: NATO MISP, Cyber Rapid Reaction Teams

### NATO Integrated Cyber Defence Centre (ICDC)
- **Role**: Operate "throughout peacetime, crisis and conflict" from SHAPE, Mons
- **Capabilities**: Alliance-wide threat picture, coordinated response

### Computer Emergency Response Teams (CERTs)
- **Role**: Respond to cyber incidents in national and NATO networks
- **Types**: Military CERTs, national CERTs (civilian), sector-specific CERTs
- **Constraint**: Civilian CERTs lack military clearances but need defensive indicators

### Defence Industrial Base Partners
- **Role**: Protect defence supply chains from cyber threats
- **Constraint**: Private sector entities with limited security clearances
- **Need**: Threat indicators relevant to defence industry targeting

## Scenario Flow

### Phase 1: Threat Detection and Initial Analysis

**Context**: UK National Cyber Security Centre detects sophisticated malware targeting NATO logistics systems. Analysis reveals a custom implant with characteristics suggesting state-sponsored origin.

**CTI Produced**:
```
INDICATOR SET A - Technical Indicators (UNCLASSIFIED)
- Malware hash: SHA256:a1b2c3d4...
- C2 domains: bad-domain-1.example, bad-domain-2.example
- C2 IP addresses: 192.0.2.1, 198.51.100.2
- YARA signatures for detection
- Network signatures (Snort/Suricata rules)
Format: STIX 2.1 bundle

INDICATOR SET B - Tactical Analysis (SECRET)
- Malware capabilities (data exfiltration, lateral movement)
- Targeted systems (NATO logistics applications)
- TTPs mapped to MITRE ATT&CK framework
- Recommended defensive measures
Format: STIX 2.1 bundle with TLP:AMBER markings

INDICATOR SET C - Attribution Intelligence (TOP SECRET//SI)
- Attributed to [NAMED STATE ACTOR]
- Collection method: [SIGINT DERIVED]
- Actor infrastructure mapping
- Related campaigns and targets
Format: STIX 2.1 bundle, UK EYES ONLY initially
```

**DCS Application**: Each indicator set wrapped in separate ZTDF envelopes with different ABAC policies. The STIX bundle structure preserved; ZTDF wraps the bundle, not individual indicators.

### Phase 2: Automated Defensive Indicator Sharing

**Context**: Technical indicators (Set A) must reach all NATO nations' defensive systems within minutes to enable blocking.

**Sharing Flow**:
1. UK originates indicator Set A as ZTDF-wrapped STIX bundle
2. ABAC policy: UNCLASSIFIED, releasable to NATO + partner nations + CERTs + defence industry
3. NATO MISP receives and distributes automatically
4. National CERTs ingest indicators directly into defensive systems (firewalls, IDS/IPS, SIEM)
5. Defence industry partners receive indicators for supply chain defence
6. No human approval required -- pre-authorised sharing policy

**Performance Requirement**: Indicators available to all authorised consumers within minutes of origination.

**Access Control**:
- All NATO nation CERTs receive Set A indicators
- Partner nation CERTs (e.g., Ukraine, Japan) receive if releasability permits
- Defence industry partners receive sanitised indicators (no attribution context)
- Audit trail tracks which organisations ingested which indicators

### Phase 3: Tactical Analysis Sharing

**Context**: Tactical analysis (Set B) shared with NATO cyber defenders for informed defence.

**Sharing Flow**:
1. UK originates Set B as ZTDF-wrapped STIX bundle
2. ABAC policy: SECRET, releasable to NATO
3. Distribution to national military CERTs and NATO NCSC
4. Human review not required (pre-authorised for NATO SECRET sharing)
5. Civilian CERTs receive sanitised version (TTPs without specific targeting details)

**Access Control**:
- NATO military CERTs see full tactical analysis
- Civilian CERTs see TTPs and defensive measures (not specific targeting details)
- Defence industry sees recommended mitigations (not malware capabilities)

### Phase 4: Attribution Intelligence (Restricted Sharing)

**Context**: Attribution intelligence (Set C) initially UK EYES ONLY, then selectively shared.

**Initial Sharing**:
1. UK originates Set C as ZTDF-wrapped bundle, UK EYES ONLY
2. UK intelligence community consumes attribution for strategic assessment
3. UK decides to share attribution with Five Eyes partners
4. ABAC policy updated: TOP SECRET, releasable to FVEY
5. Five Eyes partners receive attribution intelligence
6. Further sharing requires UK originator approval

**Subsequent Sharing Decision**:
- UK decides NATO allies need to know the attributed actor for defensive prioritisation
- UK produces sanitised attribution (names the actor, not the collection method)
- Sanitised version: SECRET, releasable to NATO
- Original collection method detail remains TOP SECRET//SI, UK/FVEY only

**Access Control**:
- UK analysts see full attribution including collection method
- FVEY partners see attribution and collection method
- NATO allies see attributed actor but not collection method
- Civilian CERTs and industry see "state-sponsored" without specific attribution

### Phase 5: Indicator Lifecycle Management

**Context**: Over time, indicators become stale, new indicators emerge, and attribution evolves.

**Indicator Updates**:
- New C2 infrastructure identified -- additional indicators added to Set A
- Actor changes TTPs -- Set B updated with new defensive measures
- Attribution confidence increases -- Set C updated
- Old indicators deprecated but retained for historical analysis

**DCS Behaviour**:
- Updated indicators inherit sharing policies from parent sets
- Deprecated indicators marked but remain accessible for historical queries
- Audit trail links indicator evolution over time
- Nations that received earlier versions automatically receive updates (if policy permits)

## Operational Constraints

1. **Speed**: Defensive indicators must reach consumers in minutes
2. **Machine Consumption**: CTI must be in formats that automated systems can ingest (STIX/TAXII)
3. **Volume**: Thousands of indicators per day during active campaigns
4. **Multi-Level**: Same incident produces CTI at multiple classification levels
5. **Non-Military Partners**: Civilian CERTs and industry need defensive data without clearances
6. **Attribution Sensitivity**: Collection methods among the most sensitive national capabilities
7. **Evolving Threat**: Indicators change rapidly; sharing must keep pace

## Technical Challenges

1. **STIX/TAXII + ZTDF Integration**: How to wrap STIX bundles in ZTDF without breaking automated consumption?
2. **Machine-Speed Policy Evaluation**: How to evaluate ABAC policies for thousands of indicators per day?
3. **Selective Sanitisation**: How to share technical indicators without attribution context automatically?
4. **Indicator Correlation**: How to prevent recipients from correlating UNCLASSIFIED indicators with SECRET context?
5. **Non-Cleared Partner Access**: How to provide defensive intelligence to entities without military clearances?
6. **Indicator Freshness**: How to ensure consumers always have the latest indicators?
7. **Cross-Platform Ingestion**: How to ensure ZTDF-wrapped CTI works with diverse SIEM/SOAR platforms?

## Acceptance Criteria

### AC1: Automated Defensive Sharing
- [ ] Technical indicators (IOCs) shared with all authorised consumers automatically
- [ ] No human approval required for pre-authorised indicator types
- [ ] Indicators available to consumers within minutes of origination
- [ ] Automated ingestion into defensive systems (SIEM, IDS/IPS, firewall)
- [ ] STIX 2.1 format preserved within ZTDF wrapper

### AC2: Multi-Level CTI Management
- [ ] Same incident produces CTI at UNCLASSIFIED, SECRET, and TOP SECRET levels
- [ ] Each level wrapped with appropriate ABAC policies
- [ ] Consumers see only CTI at their authorised level
- [ ] Relationships between levels maintained (without revealing higher-level content)

### AC3: Attribution Protection
- [ ] Collection methods protected at highest classification
- [ ] Attribution shared selectively based on originator decision
- [ ] Sanitised attribution (actor without method) produced automatically
- [ ] Originator controls enforced technically on attribution intelligence

### AC4: Non-Military Partner Sharing
- [ ] Civilian CERTs receive defensive indicators and TTPs
- [ ] Defence industry receives indicators relevant to supply chain defence
- [ ] Neither civilian CERTs nor industry receive attribution or collection methods
- [ ] Access policies enforce separation automatically

### AC5: Indicator Lifecycle
- [ ] New indicators distributed to authorised consumers automatically
- [ ] Updated indicators replace/supplement previous versions
- [ ] Deprecated indicators marked but retained for historical analysis
- [ ] Audit trail tracks indicator evolution and consumption

### AC6: Machine Interoperability
- [ ] ZTDF-wrapped CTI compatible with major SIEM platforms
- [ ] Automated TAXII feeds deliver ZTDF-wrapped STIX bundles
- [ ] Consumer systems can unwrap ZTDF and ingest STIX natively
- [ ] Performance scales to thousands of indicators per day

### AC7: Comprehensive Audit Trail
- [ ] Indicator origination logged
- [ ] Distribution to each consumer logged
- [ ] Consumer ingestion into defensive systems logged
- [ ] Attribution access logged with enhanced detail
- [ ] Audit supports damage assessment if indicators are compromised

## Success Metrics

- **Sharing Speed**: Defensive indicators available within minutes
- **Coverage**: All authorised consumers receive relevant indicators
- **Attribution Protection**: Collection methods never exposed to unauthorised consumers
- **Machine Consumption**: Automated ingestion successful across consumer platforms
- **Audit Completeness**: All indicator distribution and access logged

## Out of Scope

- Offensive cyber operations
- Cyber weapon development
- Network intrusion detection system design
- SIEM/SOAR platform selection
- Malware analysis methodology

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing -- CTI is a specialised form of intelligence sharing
- **Scenario 04**: Cross-domain sanitisation -- sanitising attribution from technical indicators
- **Scenario 06**: Intelligence fusion -- CTI fusion across national contributions

---
