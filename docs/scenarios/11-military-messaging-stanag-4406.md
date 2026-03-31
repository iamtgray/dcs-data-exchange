# Scenario 11: DCS-Enabled Military Messaging (STANAG 4406)

## Overview

STANAG 4406 defines the NATO Military Message Handling System (MMHS) -- the backbone of formal military communications for operational orders, intelligence reports, situation reports, and administrative traffic. Messages currently carry classification markings at the message level but lack data-centric encryption at the content level. This scenario explores applying DCS to military messaging to enable content-level access control, persistent originator protection, and machine-readable security metadata within the existing MMHS framework.

## Problem Statement

Military messages often contain information at multiple sensitivity levels within a single message. A situation report may contain unclassified logistics data alongside SECRET tactical positions and TOP SECRET intelligence assessments. Current MMHS marks the entire message at the highest classification of any content within it, denying access to the entire message for anyone lacking the highest clearance. This over-classification reduces information availability. Once a message is delivered, originator controls are enforced procedurally (by policy) rather than technically -- recipients can forward, copy, or extract content without the originator's knowledge or consent.

## Actors

### Message Originators
- **Role**: Create and classify military messages
- **Types**: Headquarters staff, intelligence officers, logistics planners, commanders
- **Responsibility**: Apply correct classification, caveats, and handling instructions
- **Constraint**: Must comply with national and NATO classification policies

### Message Recipients
- **Role**: Receive, read, and act on military messages
- **Types**: Vary from UNCLASSIFIED-cleared logistics staff to TOP SECRET-cleared intelligence officers
- **Constraint**: Should see only content they are authorised to access

### Message Handling System (MMHS)
- **Role**: Route, store, and deliver military messages per STANAG 4406
- **Current Capability**: Message-level classification, routing based on addressee lists
- **Desired Capability**: Content-level DCS, automated routing based on recipient attributes

### Message Guards / Cross-Domain Gateways
- **Role**: Transfer messages between security domains
- **Current Capability**: Whole-message inspection, dirty-word filtering, format validation
- **Desired Capability**: Content-level DCS inspection, policy-based paragraph release

## Scenario Flow

### Phase 1: Message Creation with Content-Level DCS

**Context**: UK Joint Force Headquarters creates a daily situation report (SITREP) for distribution to coalition partners.

**Message Structure**:
```
FROM: UK JFHQ
TO: NATO SHAPE, US EUCOM, FR CPCO, DE FHQ
SUBJECT: DAILY SITREP - OPERATION NORTHERN GUARDIAN - 15 MAR 2026

PARA 1 - EXECUTIVE SUMMARY
Classification: NATO SECRET
Releasability: All coalition partners
Content: General operational situation, no sensitive details

PARA 2 - FRIENDLY FORCE POSITIONS
Classification: NATO SECRET
Releasability: Coalition partners (UK, US, FR, DE, PL, CA)
Content: Unit locations and strengths

PARA 3 - ENEMY ASSESSMENT
Classification: UK TOP SECRET
Releasability: UK, US only (intelligence source sensitivity)
Content: Detailed enemy order of battle from UK intelligence sources

PARA 4 - LOGISTICS STATUS
Classification: NATO RESTRICTED
Releasability: All coalition partners including logistics contractors
Content: Supply levels, maintenance status, transport schedules

PARA 5 - PLANNED OPERATIONS (NEXT 24H)
Classification: NATO SECRET + OPERATION WALL SAP
Releasability: Commanders and operations staff only
Content: Planned operations with timings and objectives
```

**DCS Application**: Each paragraph wrapped in its own ZTDF envelope with appropriate ABAC policies. The message as a whole is a container of individually protected content blocks.

### Phase 2: Attribute-Based Delivery

**Context**: Message routed to multiple recipients with different clearances and roles.

**Recipient Access**:

| Recipient | Clearance | Role | Sees |
|-----------|-----------|------|------|
| UK Intelligence Analyst | UK TS | Intelligence | Paras 1, 2, 3, 4, 5 (full access) |
| US Operations Officer | TS/SCI | Operations | Paras 1, 2, 3, 4, 5 (full access, UK/US releasability) |
| French Commander | SECRET | Command | Paras 1, 2, 4, 5 (not Para 3 -- UK/US only) |
| German Logistics Officer | RESTRICTED | Logistics | Paras 1, 4 (logistics relevant, RESTRICTED cleared) |
| Polish Liaison Officer | NS | Liaison | Paras 1, 2, 4 (coalition releasability) |
| Logistics Contractor | NATO RESTRICTED | Support | Para 4 only |

**DCS Behaviour**: Each recipient's MMHS client requests decryption of each paragraph from the appropriate KAS. KAS evaluates the recipient's attributes (clearance, nationality, role, mission assignment) against each paragraph's ABAC policy. Only authorised paragraphs are decrypted and displayed. Unauthorised paragraphs show "[CONTENT NOT AVAILABLE - INSUFFICIENT CLEARANCE/ROLE]".

### Phase 3: Cross-Domain Message Transfer

**Context**: Message must traverse from UK TOP SECRET network to NATO SECRET network to reach coalition partners.

**Current Process**: Message guard inspects entire message. If any content is above NATO SECRET, the entire message is blocked or requires manual review and sanitisation before release.

**DCS-Enabled Process**:
1. Message guard receives ZTDF-wrapped message
2. Guard inspects metadata labels (ADatP-4774/4778) on each paragraph
3. Paragraphs with NATO SECRET or lower releasability pass automatically
4. Paragraphs with UK TOP SECRET are stripped (not forwarded to NATO SECRET network)
5. Recipient on NATO SECRET network receives message with Paras 1, 2, 4, 5 -- Para 3 absent
6. Audit trail logs which paragraphs were released and which were withheld

### Phase 4: Reply and Forward with Originator Control

**Context**: French commander wants to forward the SITREP summary (Para 1) to subordinate units.

**Originator Control Enforcement**:
- ZTDF policy on Para 1 permits forwarding to "coalition partners at NATO SECRET"
- French commander forwards to French subordinate units -- permitted
- French commander attempts to forward to a non-coalition partner -- denied by KAS policy
- Originator (UK JFHQ) receives audit notification that Para 1 was forwarded

**Context**: German logistics officer extracts supply data (Para 4) for a logistics planning spreadsheet.

**Originator Control Enforcement**:
- ZTDF policy on Para 4 permits extraction by logistics-role personnel
- Data retains its ZTDF wrapping even when extracted to spreadsheet
- Any further sharing of extracted data governed by original policy
- Audit trail tracks extraction and subsequent access

### Phase 5: Message Archival and Retention

**Context**: Messages archived for operational records and potential legal review.

**DCS Persistence**:
- Archived messages retain per-paragraph ZTDF wrapping
- Access policies persist in archive -- future access evaluated against then-current policies
- If classification is downgraded, policies can be updated on archived messages
- Retention period tracked per paragraph based on classification
- Compliance officers can verify archive completeness without accessing content

## Operational Constraints

1. **STANAG 4406 Compatibility**: Must work within existing MMHS framework
2. **Backward Compatibility**: Must interoperate with systems that do not support content-level DCS
3. **Performance**: Message delivery latency acceptable for military communications
4. **User Experience**: Originators should not face excessive burden applying per-paragraph policies
5. **Guard Integration**: Must work with existing message guards at domain boundaries
6. **Audit**: Every access, forwarding, and extraction event logged
7. **Offline**: Message creation must work without KAS connectivity (encrypt offline)

## Technical Challenges

1. **Per-Paragraph Encryption**: How to apply ZTDF at paragraph level within an MMHS message?
2. **Message Structure**: How to maintain MMHS message format while embedding ZTDF envelopes?
3. **Guard Integration**: How do existing message guards inspect ZTDF-wrapped content?
4. **Backward Compatibility**: What do non-DCS-aware recipients see?
5. **Template-Based Classification**: How to provide policy templates so originators do not manually tag every paragraph?
6. **Reply Handling**: How to maintain DCS on quoted content in replies?
7. **Distribution Lists**: How to handle large distribution lists efficiently with per-paragraph policies?

## Acceptance Criteria

### AC1: Content-Level Classification
- [ ] Individual paragraphs within a message can have different classification levels
- [ ] Each paragraph wrapped with its own ZTDF policy
- [ ] Message-level classification reflects highest paragraph classification
- [ ] Classification metadata follows ADatP-4774/4778 standards

### AC2: Attribute-Based Content Access
- [ ] Recipients see only paragraphs they are authorised to access
- [ ] Access decisions based on clearance, nationality, role, and mission
- [ ] Unauthorised paragraphs indicated (not silently hidden)
- [ ] Access evaluated by KAS against paragraph-level ABAC policies

### AC3: Cross-Domain Transfer
- [ ] Message guards can inspect ZTDF metadata without decrypting content
- [ ] Guards release paragraphs appropriate for the target domain
- [ ] Higher-classification paragraphs withheld at domain boundaries
- [ ] Audit trail records guard decisions

### AC4: Originator Control
- [ ] Originator defines forwarding and extraction policies per paragraph
- [ ] Recipients cannot forward beyond originator-defined releasability
- [ ] Extraction of content to other systems retains DCS wrapping
- [ ] Originator notified of forwarding and extraction events

### AC5: STANAG 4406 Compatibility
- [ ] DCS-enabled messages conform to MMHS message format
- [ ] Non-DCS-aware recipients receive message at whole-message classification
- [ ] Graceful degradation for legacy systems
- [ ] Interoperable with existing NATO message infrastructure

### AC6: User Experience
- [ ] Policy templates available for common message types (SITREP, INTREP, OPORD)
- [ ] Originators can apply per-paragraph policies with minimal additional effort
- [ ] Default policies based on message type and distribution
- [ ] Recipients experience seamless content filtering

### AC7: Comprehensive Audit Trail
- [ ] Every paragraph access logged (successful and denied)
- [ ] Forwarding and extraction events logged
- [ ] Guard release/withhold decisions logged
- [ ] Audit supports compliance and security investigations

### AC8: Offline Message Creation
- [ ] Messages can be created and encrypted without KAS connectivity
- [ ] Offline encryption uses pre-distributed public keys
- [ ] Policies embedded in message, enforced when recipients connect to KAS

## Success Metrics

- **Content Availability**: Recipients see all content they are authorised for (no over-blocking)
- **Security**: Recipients cannot access content above their authorisation
- **Originator Control**: Forwarding and extraction governed by originator policy
- **Compatibility**: Works within existing MMHS infrastructure
- **User Burden**: Minimal additional effort for message originators
- **Audit Completeness**: All access and forwarding events logged

## Out of Scope

- Rewriting STANAG 4406 specification
- Real-time chat and instant messaging (separate systems)
- Voice communications security
- Email systems outside MMHS
- Content-based automatic classification (covered in Scenario 03)

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing -- message-based intelligence exchange
- **Scenario 03**: Legacy system retrofit -- applying DCS to existing messaging infrastructure
- **Scenario 04**: Cross-domain sanitisation -- automated paragraph-level release at guards
- **Scenario 06**: Intelligence fusion -- intelligence reports disseminated via MMHS

## Key Assumptions

1. **STANAG Extension**: STANAG 4406 can be extended to carry ZTDF-wrapped content blocks
2. **Guard Capability**: Message guards can be upgraded to inspect ZTDF metadata
3. **Template Availability**: Policy templates reduce originator burden
4. **KAS Infrastructure**: KAS accessible to MMHS clients across NATO networks
5. **Backward Compatibility**: Non-DCS systems receive whole-message at highest classification

---
