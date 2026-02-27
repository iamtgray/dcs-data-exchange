# Scenario 04: Cross-Domain Automated Sanitisation

## Overview

Military organisations operate multiple classification domains (e.g., TOP SECRET, SECRET, UNCLASSIFIED networks) that are physically or logically separated. Information frequently needs to move from higher classification to lower classification domains, but current processes rely on manual review and redaction. This scenario explores automated sanitisation that can intelligently remove sensitive content while preserving operational value, enabling faster and more consistent cross-domain information flow.

## Problem Statement

Moving classified information to lower classification levels currently requires extensive manual review by trained personnel. This process is slow (hours to days), inconsistent (different reviewers make different decisions), and doesn't scale to modern data volumes. Automated sanitisation could accelerate information sharing whilst maintaining security, but requires new standards for content analysis, redaction rules, and derivative work tracking.

## Actors

### High-Side Domain
- **Classification**: TOP SECRET / Sensitive Compartmented Information (SCI)
- **Content**: Intelligence reports, operational plans, sensor data with sensitive sources/methods
- **Users**: Intelligence analysts, operational planners with TS/SCI clearances

### Low-Side Domain
- **Classification**: SECRET or UNCLASSIFIED
- **Content**: Sanitised versions of high-side information
- **Users**: Broader audience including coalition partners, lower-cleared personnel

### Cross-Domain Solution (CDS)
- **Role**: Gateway between classification domains
- **Current Capability**: Manual review, dirty word blocking, format checking
- **Desired Capability**: Automated content analysis, intelligent sanitisation, derivative work tracking

### Sanitisation Engine (New Capability)
- **Role**: Analyse content, identify sensitive elements, apply redaction rules
- **Capabilities**: Natural language processing, entity recognition, classification reasoning
- **Output**: Sanitised document + audit trail + relationship tracking

## Scenario Flow

### Phase 1: Content Analysis

**Context**: Intelligence analyst on high-side creates report containing mix of sensitivity levels.

**Content Example**:
```
OPERATION WALL UPDATE - 15 JAN 2026

Enemy forces observed moving through GRID 12345678 (REDACTED LOCATION).
Movement detected by SIGINT platform BLACKBIRD (SENSITIVE SOURCE).
Estimated 200 personnel with armoured vehicles.
Movement pattern suggests preparation for offensive operations.
Recommend increased surveillance of GRID 12345678.
```

**Sanitisation Engine Actions**:
- Identify sensitive elements:
  - "GRID 12345678" → Specific location (TS)
  - "SIGINT platform BLACKBIRD" → Source/method (TS/SCI)
  - "200 personnel with armoured vehicles" → Tactical detail (SECRET)
  - "Movement pattern suggests..." → Analysis (SECRET)
- Determine what can be released at SECRET level
- Apply redaction rules

### Phase 2: Automated Sanitisation

**Sanitisation Rules Applied**:
1. **Remove specific locations**: Replace with general area description
2. **Remove source/method details**: Replace with generic "intelligence sources"
3. **Preserve tactical value**: Keep force estimates and analysis
4. **Maintain coherence**: Ensure sanitised version is readable and useful

**Sanitised Output (SECRET level)**:
```
OPERATION WALL UPDATE - 15 JAN 2026

Enemy forces observed moving through NORTHERN SECTOR.
Movement detected by intelligence sources.
Estimated 200 personnel with armoured vehicles.
Movement pattern suggests preparation for offensive operations.
Recommend increased surveillance of NORTHERN SECTOR.
```

### Phase 3: Human Review

**Context**: Automated sanitisation complete, but requires human verification.

**Review Process**:
- Reviewer sees original (TS) and sanitised (SECRET) versions side-by-side
- Highlights show what was redacted and why
- Reviewer can:
  - Approve (sanitisation correct)
  - Modify (adjust redactions)
  - Reject (too much/too little removed)
- Feedback improves sanitisation rules over time

### Phase 4: Cross-Domain Transfer

**Context**: Sanitised document approved for release to SECRET domain.

**Transfer Process**:
- Original TS document remains on high-side
- Sanitised SECRET document transferred through CDS
- Relationship tracked: "SECRET doc X derived from TS doc Y"
- Audit trail records: who sanitised, who reviewed, what was removed
- Metadata labels SECRET document with derivation information

### Phase 5: Derivative Work Tracking

**Context**: SECRET document now on low-side, but relationship to high-side original must be maintained.

**Tracking Requirements**:
- If high-side original is updated, flag low-side derivative for review
- If high-side original is reclassified, update low-side derivative
- If high-side original is deleted, consider impact on low-side derivative
- Audit trail links all versions across domains

## Operational Constraints

1. **Security**: Sanitisation errors that leak classified information are unacceptable
2. **Accuracy**: Sanitised documents must preserve operational value
3. **Speed**: Sanitisation must be faster than manual review (minutes vs hours)
4. **Consistency**: Same content should be sanitised the same way every time
5. **Auditability**: All sanitisation decisions must be logged and explainable
6. **Human Oversight**: Automated sanitisation requires human review before release
7. **Reversibility**: Cannot reconstruct high-side content from low-side sanitised version
8. **Domain Separation**: Sanitisation engine must not bridge classification domains

## Technical Challenges

1. **Content Understanding**: How to identify sensitive elements in unstructured text?
2. **Context Awareness**: How to determine if information is sensitive based on context?
3. **Redaction Granularity**: Document, section, paragraph, sentence, or word level?
4. **Coherence Preservation**: How to maintain readability after redaction?
5. **Classification Reasoning**: How to determine appropriate classification of sanitised output?
6. **Relationship Tracking**: How to link high-side originals to low-side derivatives?
7. **Version Management**: How to handle updates to high-side documents?
8. **Rule Management**: How to define, update, and audit sanitisation rules?
9. **Multi-Format Support**: How to sanitise text, images, structured data, multimedia?
10. **Error Handling**: What happens when sanitisation engine makes mistakes?

## Acceptance Criteria

### AC1: Automated Content Analysis
- [ ] System identifies sensitive elements in unstructured text
- [ ] Recognises entities (locations, people, organisations, capabilities)
- [ ] Understands classification markers and caveats
- [ ] Identifies source/method information
- [ ] Determines context-dependent sensitivity
- [ ] Analysis completes quickly enough for operational use

### AC2: Intelligent Redaction
- [ ] Removes sensitive elements whilst preserving operational value
- [ ] Maintains document coherence and readability
- [ ] Applies consistent redaction rules
- [ ] Supports multiple redaction strategies (remove, replace, generalise)
- [ ] Handles nested classifications (classified section in unclassified document)
- [ ] Redaction is irreversible (cannot reconstruct original from sanitised version)

### AC3: Classification Determination
- [ ] Automatically determines appropriate classification of sanitised output
- [ ] Considers highest remaining classification in document
- [ ] Applies appropriate caveats and handling restrictions
- [ ] Labels derivative work with correct classification markings
- [ ] Explains classification reasoning

### AC4: Human Review Workflow
- [ ] Presents original and sanitised versions side-by-side
- [ ] Highlights redacted elements with explanations
- [ ] Allows reviewer to approve, modify, or reject
- [ ] Tracks reviewer decisions and feedback
- [ ] Improves sanitisation rules based on feedback
- [ ] Maintains audit trail of review process

### AC5: Cross-Domain Transfer
- [ ] Integrates with existing Cross-Domain Solutions
- [ ] Transfers sanitised documents securely
- [ ] Prevents high-side content from leaking to low-side
- [ ] Validates sanitisation before transfer
- [ ] Logs all cross-domain transfers

### AC6: Derivative Work Tracking
- [ ] Links low-side derivatives to high-side originals
- [ ] Tracks version history across domains
- [ ] Flags derivatives when originals are updated
- [ ] Maintains relationship metadata
- [ ] Supports queries: "What low-side docs came from this high-side doc?"
- [ ] Supports reverse queries: "What high-side doc did this come from?"

### AC7: Audit Trail
- [ ] Logs all sanitisation operations
- [ ] Records what was redacted and why
- [ ] Tracks who reviewed and approved
- [ ] Logs cross-domain transfers
- [ ] Maintains tamper-proof audit logs
- [ ] Supports compliance and security investigations

### AC8: Rule Management
- [ ] Administrators can define sanitisation rules
- [ ] Rules specify what to redact and how
- [ ] Rules can be organisation-specific or domain-specific
- [ ] Rule updates take effect appropriately
- [ ] Rule conflicts detected and resolved
- [ ] Rules are versioned and auditable

### AC9: Multi-Format Support
- [ ] Sanitises text documents (Word, PDF, plain text)
- [ ] Sanitises structured data (XML, JSON, databases)
- [ ] Sanitises images (redact sensitive portions)
- [ ] Sanitises multimedia (video, audio)
- [ ] Preserves format and usability after sanitisation

### AC10: Error Handling and Safety
- [ ] Bias towards over-redaction (fail secure)
- [ ] Flags uncertain sanitisation decisions for human review
- [ ] Prevents release if sanitisation confidence is low
- [ ] Provides confidence scores for sanitisation decisions
- [ ] Supports manual override with justification

### AC11: Performance and Scalability
- [ ] Sanitises typical documents quickly
- [ ] Handles large documents efficiently
- [ ] Scales to organisational document volumes
- [ ] Minimal impact on cross-domain transfer throughput

### AC12: Standards Compliance
- [ ] Follows classification marking standards
- [ ] Integrates with existing security policies
- [ ] Supports multiple classification systems (national, NATO, coalition)
- [ ] Complies with records management requirements
- [ ] Meets cross-domain solution certification requirements

## Success Metrics

- **Sanitisation Speed**: Significantly faster than manual review
- **Accuracy**: Very high correct redaction rate (suitable for operational security)
- **False Positive Rate**: Low over-redaction (preserves operational value)
- **False Negative Rate**: Very low under-redaction (critical security risk)
- **Human Review Time**: Reduced compared to full manual review
- **Consistency**: Same content sanitised the same way across reviewers
- **Throughput**: Increased cross-domain information flow
- **User Satisfaction**: Reviewers and consumers find sanitised content useful

## Example Use Cases

### Use Case 1: Intelligence Report Sanitisation
**High-Side (TS/SCI)**: Detailed intelligence report with sources, methods, specific locations, intercepts.

**Sanitisation**: Remove sources/methods, generalise locations, preserve threat analysis.

**Low-Side (SECRET)**: Threat assessment useful for operational planning without compromising sources.

### Use Case 2: Operational Plan Downgrade
**High-Side (TS)**: Detailed operational plan with unit locations, timings, capabilities.

**Sanitisation**: Remove specific timings and locations, preserve general concept of operations.

**Low-Side (SECRET)**: Concept of operations for coordination with coalition partners.

### Use Case 3: Sensor Data Release
**High-Side (TS)**: Raw sensor data revealing collection capabilities and coverage.

**Sanitisation**: Aggregate data, remove capability indicators, preserve tactical picture.

**Low-Side (SECRET)**: Tactical situation awareness without revealing sensor capabilities.

## Out of Scope

- Real-time streaming data sanitisation
- Sanitisation of data in motion (network traffic)
- Encryption/decryption (separate concern, handled by TDF/ZTDF)
- Cross-domain solution hardware/infrastructure
- AI/ML model training (assume pre-trained models available)
- Foreign language translation

## Related Scenarios

- **Scenario 03**: Legacy system retrofit - provides content labelling foundation
- **Scenario 01**: Coalition sharing - sanitised content shared with allies
- **Scenario 06**: Mission-based sharing - sanitised content for mission partners

## Key Assumptions

1. **Content is Analysable**: Documents are in formats that can be parsed
2. **Rules are Definable**: Organisations can articulate sanitisation rules
3. **Human Review Available**: Automated sanitisation requires human verification
4. **CDS Integration Possible**: Can integrate with existing cross-domain solutions
5. **Accuracy Sufficient**: Very high accuracy meets security requirements
6. **Performance Acceptable**: Faster than manual review is acceptable

## New Standards Required

### 1. Sanitisation Markup Language (SML)
**Purpose**: Standard format for marking sensitive elements and redaction rules

**Capabilities**:
- Tag sensitive entities (locations, people, capabilities)
- Specify redaction actions (remove, replace, generalise)
- Define classification reasoning
- Support multiple classification systems

### 2. Derivative Work Metadata Standard
**Purpose**: Track relationships between high-side originals and low-side derivatives

**Capabilities**:
- Link documents across classification domains
- Track version history and updates
- Record sanitisation provenance
- Support bidirectional queries

### 3. Sanitisation Audit Format
**Purpose**: Standard format for logging sanitisation operations

**Capabilities**:
- Record what was redacted and why
- Track human review decisions
- Log cross-domain transfers
- Support compliance investigations

### 4. Classification Reasoning Schema
**Purpose**: Explain why content has specific classification

**Capabilities**:
- Document classification logic
- Support automated classification determination
- Enable human review and override
- Integrate with existing classification guides

## Risk Considerations

**Security Risks**:
- Under-sanitisation leaks classified information to lower domain
- Sanitisation engine compromised to deliberately leak information
- Relationship tracking reveals high-side document existence to low-side users
- Audit logs compromised to hide sanitisation errors

**Operational Risks**:
- Over-sanitisation removes too much, making documents useless
- Inconsistent sanitisation confuses users
- Slow sanitisation creates bottleneck
- Human review becomes rubber-stamp process

**Mitigation Strategies**:
- Bias towards over-redaction (fail secure)
- Extensive testing before operational deployment
- Mandatory human review for all sanitisation
- Continuous monitoring and improvement
- Regular security audits of sanitisation engine

---

*This scenario addresses the critical gap in current cross-domain solutions: the need for automated, intelligent sanitisation that can accelerate information flow whilst maintaining security. Success requires new standards beyond current TDF/ZTDF capabilities.*
