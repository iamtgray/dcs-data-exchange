# Scenario 06: Multi-National Intelligence Fusion Centre

## Overview

Intelligence fusion centres bring together analysts from multiple nations to create a shared intelligence picture. Each nation contributes intelligence with originator controls, and analysts see a fused picture based on their clearances and need-to-know. The challenge is enabling effective intelligence fusion whilst respecting each nation's caveats, protecting sources and methods, and maintaining attribution so nations know which intelligence came from which partner.

## Problem Statement

Traditional intelligence sharing uses bilateral agreements and manual coordination, creating information silos and delayed fusion. Modern threats require real-time intelligence fusion across multiple nations, but current systems struggle to enforce complex originator controls, maintain attribution, and generate multi-level products (tearline reports) automatically. Nations need to contribute intelligence whilst retaining control over their sources and methods.

## Actors

### Contributing Nations (5-7 nations)
- **Role**: Provide intelligence to fusion centre
- **Contributions**: SIGINT, HUMINT, IMINT, OSINT, analysis
- **Controls**: Each nation specifies who can see their intelligence
- **Caveats**: REL TO (releasable to), NOFORN (no foreign nationals), ORIGINATOR CONTROLLED

### Fusion Centre Analysts
- **Clearances**: Range from SECRET to TOP SECRET/SCI
- **Nationalities**: Multiple nations represented
- **Roles**: All-source analysts, targeting analysts, threat analysts
- **Access**: Based on clearance, nationality, and need-to-know

### Intelligence Consumers
- **Military Commanders**: Need operational intelligence
- **Policy Makers**: Need strategic assessments
- **Coalition Partners**: Need threat information
- **Clearances**: Vary from UNCLASSIFIED to TOP SECRET

### Fusion Centre Infrastructure
- **Role**: Enforce originator controls, maintain attribution, generate products
- **Capabilities**: Intelligence database, fusion tools, product generation
- **Security**: Multi-level security, audit trails, access controls

## Scenario Flow

### Phase 1: Intelligence Contribution

**Context**: Five nations (UK, US, France, Germany, Poland) contribute intelligence to NATO fusion centre.

**UK Contribution**:
```
Classification: UK TOP SECRET
Originator: UK
Releasability: REL TO UK, US, FR
Caveat: UK EYES ONLY (no further dissemination)
Content: HUMINT report on terrorist financing network
Source Protection: Sources and methods must not be revealed
```

**US Contribution**:
```
Classification: TOP SECRET//SI (Special Intelligence)
Originator: US
Releasability: REL TO NATO
Caveat: NOFORN (no foreign nationals) for source details
Content: SIGINT intercepts of terrorist communications
Source Protection: Collection method must not be revealed
```

**French Contribution**:
```
Classification: TRÈS SECRET DÉFENSE
Originator: FR
Releasability: REL TO UK, US, FR, DE
Caveat: ORIGINATOR CONTROLLED
Content: IMINT satellite imagery of terrorist training camp
Source Protection: Satellite capabilities must not be revealed
```

### Phase 2: Analyst Access Based on Attributes

**UK Analyst (TS clearance, UK national)**:
- ✅ Sees UK HUMINT report (UK national, TS clearance, REL TO UK)
- ✅ Sees US SIGINT intercepts (TS clearance, REL TO NATO) but NOT source details (NOFORN)
- ✅ Sees French IMINT imagery (TS clearance, REL TO UK)
- ❌ Cannot see German intelligence marked "DE EYES ONLY"

**US Analyst (TS/SCI clearance, US national)**:
- ✅ Sees UK HUMINT report (TS clearance, REL TO US)
- ✅ Sees US SIGINT intercepts including source details (US national, TS/SCI)
- ❌ Cannot see French IMINT imagery (not REL TO US)
- ✅ Sees Polish intelligence marked "REL TO NATO"

**German Analyst (SECRET clearance, DE national)**:
- ❌ Cannot see UK HUMINT report (requires TS clearance)
- ❌ Cannot see US SIGINT intercepts (requires TS clearance)
- ✅ Sees French IMINT imagery (SECRET clearance sufficient, REL TO DE)
- ✅ Sees German intelligence marked "DE EYES ONLY"

### Phase 3: Intelligence Fusion

**Context**: Analysts from multiple nations collaborate to create fused intelligence picture.

**Fusion Process**:
1. Each analyst sees intelligence they're authorised for
2. Analysts identify connections and patterns
3. Fusion tool aggregates intelligence respecting all caveats
4. Fused picture shows:
   - What each analyst contributed
   - Attribution (which nation provided what)
   - Confidence levels
   - Source protection (no sources/methods revealed)

**Fused Intelligence Picture**:
```
TERRORIST NETWORK ASSESSMENT

Financing Network (UK source):
- Network identified operating in [LOCATION]
- Funding sources: [DETAILS]
- Attribution: UK intelligence

Communications (US source):
- Intercepts indicate planning for attack
- Timeline: [DETAILS]
- Attribution: US intelligence
- Collection method: [REDACTED - NOFORN]

Training Camp (FR source):
- Satellite imagery confirms training activity
- Location: [COORDINATES]
- Attribution: French intelligence
```

### Phase 4: Tearline Report Generation

**Context**: Fused intelligence must be disseminated at multiple classification levels.

**Automatic Tearline Generation**:

**TOP SECRET Version** (for TS-cleared analysts):
- Full intelligence picture
- All sources and methods
- Detailed attribution
- Confidence assessments

**SECRET Version** (for SECRET-cleared commanders):
- Threat assessment and recommendations
- General attribution ("allied intelligence sources")
- No sources or methods
- Sanitised details

**UNCLASSIFIED Version** (for public affairs, coalition partners):
- General threat information
- No attribution
- No operational details
- Suitable for public release

**Automatic Generation Process**:
- System identifies highest classification in fused product
- Generates versions at each classification level
- Applies sanitisation rules per level
- Maintains relationship between versions
- Tracks which high-side intelligence contributed to low-side products

### Phase 5: Originator Control and Revocation

**Context**: UK discovers their HUMINT source has been compromised. Must revoke access to all UK-contributed intelligence.

**Revocation Process**:
- UK issues revocation for all intelligence from compromised source
- System identifies all affected intelligence reports
- Access immediately revoked for all analysts
- Fused products containing UK intelligence flagged for review
- Tearline reports derived from UK intelligence marked for update
- Audit trail records revocation and impact

**Impact**:
- Analysts lose access to UK HUMINT reports
- Fused intelligence picture updated to remove UK contributions
- Tearline reports regenerated without UK intelligence
- Consumers notified of updated assessments

## Operational Constraints

1. **Originator Control**: Contributing nation retains control over their intelligence
2. **Attribution**: Analysts must know which nation provided which intelligence
3. **Source Protection**: Sources and methods must not be revealed
4. **Multi-Level Access**: Analysts with different clearances work in same facility
5. **Real-Time Fusion**: Intelligence fusion must happen quickly
6. **Tearline Generation**: Automatic generation of multi-level products
7. **Revocation**: Originators can revoke access to their intelligence
8. **Audit Trail**: Complete record of who accessed what intelligence

## Technical Challenges

1. **Complex Access Control**: How to enforce originator controls, clearances, nationalities, and caveats simultaneously?
2. **Attribution Preservation**: How to maintain attribution through fusion process?
3. **Source Protection**: How to show intelligence without revealing sources/methods?
4. **Automatic Tearline Generation**: How to automatically sanitise for different classification levels?
5. **Fusion with Caveats**: How to fuse intelligence with different releasability restrictions?
6. **Revocation Propagation**: How to revoke access and update derived products?
7. **Multi-Level Security**: How to support analysts with different clearances in same facility?
8. **Performance**: How to provide real-time access to large intelligence databases?

## Acceptance Criteria

### AC1: Originator-Controlled Access
- [ ] Intelligence labelled with originator nation
- [ ] Originator specifies releasability (REL TO nations)
- [ ] Originator specifies caveats (NOFORN, EYES ONLY, etc.)
- [ ] Access decisions respect all originator controls
- [ ] Originator can update controls on already-shared intelligence

### AC2: Multi-Attribute Access Control
- [ ] Access based on clearance level (SECRET, TOP SECRET, SCI)
- [ ] Access based on nationality (UK, US, FR, etc.)
- [ ] Access based on role (analyst, commander, policy maker)
- [ ] Access based on need-to-know (specific intelligence topics)
- [ ] All attributes evaluated simultaneously

### AC3: Attribution Preservation
- [ ] Intelligence clearly labelled with originating nation
- [ ] Attribution maintained through fusion process
- [ ] Fused products show which nations contributed
- [ ] Analysts can query: "Show me all UK intelligence on topic X"
- [ ] Attribution visible at appropriate classification level

### AC4: Source Protection
- [ ] Sources and methods redacted based on caveats
- [ ] NOFORN content hidden from foreign nationals
- [ ] Collection methods protected
- [ ] Analysts see intelligence without compromising sources
- [ ] Source protection enforced even in fused products

### AC5: Automatic Tearline Generation
- [ ] System generates products at multiple classification levels
- [ ] TOP SECRET version includes all details
- [ ] SECRET version sanitises sources/methods
- [ ] UNCLASSIFIED version suitable for public release
- [ ] Tearlines maintain operational value at each level
- [ ] Relationship between versions tracked

### AC6: Intelligence Fusion
- [ ] Analysts see intelligence they're authorised for
- [ ] Fusion tools aggregate intelligence respecting caveats
- [ ] Fused picture shows connections and patterns
- [ ] Attribution preserved in fused products
- [ ] Confidence levels and source quality indicated

### AC7: Revocation and Updates
- [ ] Originator can revoke access to their intelligence
- [ ] Revocation takes effect immediately
- [ ] Derived products (fused intelligence, tearlines) updated
- [ ] Consumers notified of revoked/updated intelligence
- [ ] Audit trail records revocation and impact

### AC8: Comprehensive Audit Trail
- [ ] All access attempts logged (successful and denied)
- [ ] Logs include: analyst, intelligence accessed, timestamp, decision
- [ ] Originator can audit who accessed their intelligence
- [ ] Fusion centre can audit all intelligence access
- [ ] Audit logs support compliance and security investigations

### AC9: Multi-Level Security
- [ ] Analysts with different clearances work in same facility
- [ ] Each analyst sees only intelligence they're authorised for
- [ ] No inadvertent spillage between classification levels
- [ ] Visual indicators show classification level of displayed intelligence

### AC10: Performance and Scalability
- [ ] Real-time access to intelligence database
- [ ] Fast query and retrieval
- [ ] Scales to large intelligence volumes
- [ ] Supports many concurrent analysts
- [ ] Minimal latency for access decisions

## Success Metrics

- **Access Accuracy**: Analysts see all and only intelligence they're authorised for
- **Attribution Accuracy**: Originating nation correctly identified for all intelligence
- **Source Protection**: No sources/methods revealed to unauthorised personnel
- **Tearline Quality**: Sanitised products maintain operational value
- **Fusion Effectiveness**: Analysts can identify connections across national contributions
- **Revocation Speed**: Access revoked and products updated quickly
- **Audit Completeness**: All access attempts logged
- **User Satisfaction**: Analysts find fusion centre effective for collaboration

## Example Use Cases

### Use Case 1: Counter-Terrorism Fusion
**Participants**: Five Eyes nations (UK, US, CA, AU, NZ)
**Intelligence**: SIGINT, HUMINT, IMINT on terrorist networks
**Caveats**: Each nation has different releasability restrictions
**Products**: Fused threat assessments at TS, S, and UNCLASS levels

### Use Case 2: Cyber Threat Intelligence
**Participants**: NATO nations
**Intelligence**: Malware samples, vulnerability data, attribution analysis
**Caveats**: Offensive capabilities marked NOFORN
**Products**: Defensive signatures (widely shared), offensive capabilities (restricted)

### Use Case 3: Regional Stability Assessment
**Participants**: Coalition partners (military and civilian)
**Intelligence**: Political analysis, economic data, military capabilities
**Caveats**: Military intelligence restricted, economic data widely shared
**Products**: Stability assessments for policy makers at multiple classification levels

## Out of Scope

- Real-time tactical intelligence (separate system)
- Long-term intelligence archival (separate system)
- Cross-domain transfers (covered in Scenario 04)
- Mission-based sharing (covered in Scenario 05)

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing - bilateral intelligence sharing
- **Scenario 04**: Cross-domain sanitisation - tearline generation
- **Scenario 05**: Mission-based sharing - time-limited intelligence sharing

## Key Assumptions

1. **Trust Framework**: Nations trust fusion centre infrastructure
2. **Classification Equivalence**: Nations agree on classification level mappings
3. **Originator Authority**: Originating nation has final say on access
4. **Audit Requirements**: All nations agree to comprehensive audit trails
5. **Technical Capability**: Nations can integrate with fusion centre systems

## Risk Considerations

**Security Risks**:
- Originator controls bypassed, exposing sources/methods
- Attribution lost, preventing accountability
- Tearline generation leaks classified information to lower levels
- Revocation fails, leaving compromised intelligence accessible

**Operational Risks**:
- Over-restrictive caveats prevent effective fusion
- Attribution creates information silos
- Tearline generation removes too much, making products useless
- Revocation disrupts ongoing operations

**Mitigation Strategies**:
- Rigorous testing of access control enforcement
- Clear policies on originator controls and caveats
- Human review of automatically generated tearlines
- Graceful revocation with notification to affected users
- Regular security audits and compliance reviews

---

*This scenario enables effective multi-national intelligence fusion whilst respecting each nation's sovereignty, protecting sources and methods, and maintaining accountability through attribution and audit trails.*
