# Scenario 03: Legacy System Data-Centric Security Retrofit

## Overview

NATO organizations operate numerous legacy applications that were not designed with data-centric security principles. These systems contain mixed-sensitivity information (from unclassified to highly classified) but lack granular access controls. The challenge is to retrofit data-centric security onto these systems without rewriting the applications, enabling dynamic content filtering based on user permissions.

## Problem Statement

Legacy systems display all information to authenticated users regardless of their specific clearances or need-to-know. This violates data-centric security principles and creates operational and compliance risks. The system must become contextually aware of data sensitivity and apply appropriate labels/metadata to control what each user can see.

## Actors

### Legacy Application
- **Type**: Existing NATO information system (e.g., intelligence database, operational planning tool, logistics system)
- **Architecture**: Monolithic application, not designed for DCS
- **Data Model**: Mixed sensitivity data in same database/interface
- **Authentication**: Existing user authentication (LDAP, AD, PKI)
- **Constraints**: Cannot be rewritten or significantly modified

### Users
- **Clearance Levels**: Range from unclassified to CTS (Cosmic Top Secret)
- **Special Access Programs**: Various SAPs and compartments
- **Nationality**: Multiple NATO nations
- **Roles**: Analysts, operators, commanders, administrators

### DCS Retrofit Layer
- **Role**: Intermediary between users and legacy application
- **Capabilities**: Content analysis, labeling, policy enforcement, filtering
- **Integration**: Must work with existing authentication and data stores

## Scenario Flow

### Phase 1: User Access Request

**Context**: User authenticates to legacy system through normal process.

**Action**: User requests to view information (e.g., opens intelligence report, queries database, views operational plan).

**Current Behavior**: System displays all information user has database access to, regardless of sensitivity.

**Desired Behavior**: System analyzes content, applies labels, and filters display based on user's clearance/permissions.

### Phase 2: Content Analysis and Labeling

**Context**: Legacy system contains unlabeled data of varying sensitivity.

**Challenge**: System must automatically:
- Identify sensitive information within documents/records
- Determine appropriate classification level
- Identify required special access programs
- Apply metadata labels to content

**Examples**:
- Intelligence report mentioning specific operation → Label: CTS + Operation WALL
- Logistics data with unit locations → Label: NS
- Administrative information → Label: Unclassified
- Mixed document with multiple sensitivity levels → Label: Highest level + all required SAPs

### Phase 3: Policy Evaluation

**Context**: Content is now labeled with sensitivity metadata.

**Action**: System evaluates user's attributes against content labels:
- User clearance level vs content classification
- User SAP memberships vs content SAP requirements
- User nationality vs content releasability
- User role vs content need-to-know

**Decision**: Grant full access, partial access (redacted), or deny access.

### Phase 4: Dynamic Content Filtering

**Context**: Policy evaluation determines what user can see.

**Action**: System dynamically filters content:
- **Full Access**: Display complete content
- **Partial Access**: Redact sensitive portions, display remainder
- **Deny Access**: Hide content entirely or show "access denied" message

**User Experience**: Seamless - user sees only what they're authorized to see, without knowing what's been filtered.

### Phase 5: Audit and Compliance

**Context**: All access attempts and filtering decisions must be logged.

**Action**: System records:
- User identity and attributes
- Content accessed (or attempted)
- Labels applied to content
- Policy decision (grant/partial/deny)
- Timestamp and context

**Purpose**: Compliance, security monitoring, incident investigation.

## Operational Constraints

1. **No Application Rewrite**: Legacy application code cannot be significantly modified
2. **Existing Authentication**: Must integrate with current authentication systems
3. **Performance**: Minimal latency impact (suitable for interactive use)
4. **Transparency**: Users should not notice the DCS layer (seamless experience)
5. **Accuracy**: Content labeling must be very highly accurate (suitable for operational security)
6. **Scalability**: Must handle existing user load and data volumes
7. **Backward Compatibility**: System must continue to function if DCS layer fails
8. **Data Variety**: Handle multiple content types (text, images, structured data, documents)

## Technical Challenges

1. **Automatic Content Classification**: How to accurately identify sensitive information in unlabeled data?
2. **Context Understanding**: How to determine appropriate labels based on content context?
3. **Integration Architecture**: Where does DCS layer sit (proxy, middleware, database layer)?
4. **Performance**: How to analyze and label content in real-time without impacting user experience?
5. **Mixed Sensitivity Content**: How to handle documents with multiple classification levels?
6. **Granularity**: What level of granularity (document, paragraph, sentence, field)?
7. **Label Persistence**: Should labels be stored or computed on-demand?
8. **Policy Management**: How to define and update labeling and access policies?
9. **False Positives/Negatives**: How to handle misclassification?
10. **Legacy Data Formats**: How to parse and analyze diverse legacy data formats?

## Acceptance Criteria

### AC1: Automatic Content Labeling
- [ ] System automatically analyzes unlabeled content
- [ ] Identifies classification level (Unclassified, NS, CTS, etc.)
- [ ] Identifies required SAPs and compartments
- [ ] Applies metadata labels to content
- [ ] Labeling accuracy is very high (suitable for operational use)
- [ ] Labeling completes with low latency (suitable for interactive use)

### AC2: User Attribute Integration
- [ ] System retrieves user clearance level from existing authentication
- [ ] System retrieves user SAP memberships
- [ ] System retrieves user nationality and role
- [ ] Integration works with LDAP, Active Directory, and PKI systems
- [ ] User attributes cached for fast lookup

### AC3: Policy-Based Access Control
- [ ] System evaluates user attributes against content labels
- [ ] Enforces clearance level requirements
- [ ] Enforces SAP requirements
- [ ] Enforces nationality-based releasability
- [ ] Enforces need-to-know based on role
- [ ] Policy evaluation completes with very low latency

### AC4: Dynamic Content Filtering
- [ ] Full access: Display complete content when authorized
- [ ] Partial access: Redact sensitive portions, display remainder
- [ ] Deny access: Hide content or show access denied message
- [ ] Filtering preserves document structure and readability
- [ ] User cannot detect what has been filtered
- [ ] Filtering works for text, structured data, and documents

### AC5: Granular Filtering
- [ ] Filter at document level (show/hide entire document)
- [ ] Filter at section level (show/hide sections within document)
- [ ] Filter at paragraph level (redact specific paragraphs)
- [ ] Filter at field level (redact database fields)
- [ ] Maintain context and readability after filtering

### AC6: Multiple Content Types
- [ ] Handle text documents (Word, PDF, plain text)
- [ ] Handle structured data (database records, XML, JSON)
- [ ] Handle images (redact sensitive portions)
- [ ] Handle mixed media documents
- [ ] Consistent labeling across content types

### AC7: Seamless Integration
- [ ] No changes required to legacy application code
- [ ] Works with existing authentication mechanisms
- [ ] Transparent to end users (no new login, no UI changes)
- [ ] Graceful degradation if DCS layer fails (fail-open or fail-closed based on policy)
- [ ] Compatible with existing backup and recovery procedures

### AC8: Performance
- [ ] Content labeling completes with low latency
- [ ] Policy evaluation completes with very low latency
- [ ] User attribute lookup is fast
- [ ] Total added latency is minimal and acceptable for interactive use
- [ ] No significant degradation of legacy application performance
- [ ] Scales to existing user load without performance issues

### AC9: Comprehensive Audit Trail
- [ ] Log all access attempts (successful and denied)
- [ ] Log content labels applied
- [ ] Log policy decisions (grant/partial/deny)
- [ ] Log user attributes at time of access
- [ ] Log redactions performed
- [ ] Logs tamper-proof and retained per compliance requirements
- [ ] Audit query interface for security monitoring

### AC10: Policy Management
- [ ] Administrators can define labeling rules
- [ ] Administrators can define access policies
- [ ] Policy updates take effect immediately (or within X minutes)
- [ ] Policy versioning and rollback capability
- [ ] Policy testing/simulation before deployment
- [ ] Policy conflicts detected and reported

### AC11: Accuracy and Reliability
- [ ] Content classification accuracy is very high (suitable for operational security)
- [ ] False positive rate is low (over-classification minimized)
- [ ] False negative rate is very low (under-classification is critical security risk)
- [ ] Manual override capability for misclassified content
- [ ] Feedback mechanism to improve classification over time

### AC12: Mixed Sensitivity Handling
- [ ] Correctly identify multiple classification levels in single document
- [ ] Apply highest classification level to document metadata
- [ ] Enable granular filtering within mixed documents
- [ ] Preserve document coherence after filtering
- [ ] Handle nested classifications (classified section within unclassified document)

## Success Metrics

- **Classification Accuracy**: Very high correct labeling rate on test dataset
- **Performance Impact**: Minimal added latency (acceptable for interactive use)
- **User Satisfaction**: Majority of users report seamless experience
- **Security Improvement**: All sensitive content protected by access controls
- **Audit Completeness**: All access attempts logged
- **False Negative Rate**: Very low (critical - under-classification is security risk)
- **Deployment Time**: Reasonable timeframe to retrofit existing system
- **Maintenance Overhead**: Minimal increase in system administration effort

## Example Use Cases

### Use Case 1: Intelligence Database
**Legacy System**: Intelligence database with reports from multiple sources and classification levels mixed together.

**Current Problem**: Analyst with NS clearance sees CTS information they shouldn't access.

**DCS Solution**: 
- System analyzes each report, identifies CTS content
- Labels reports with appropriate classification
- Analyst queries database, sees only NS and below reports
- CTS reports hidden from analyst's view
- Audit log records analyst's query and filtered results

### Use Case 2: Operational Planning Tool
**Legacy System**: Planning tool with operational plans containing mixed sensitivity information.

**Current Problem**: User without WALL SAP sees operation details they shouldn't know.

**DCS Solution**:
- System analyzes plan, identifies WALL SAP content
- Labels sections requiring WALL access
- User opens plan, sees general information
- WALL SAP sections redacted with "[REDACTED - WALL SAP REQUIRED]"
- User unaware of what specific information is hidden
- Audit log records partial access

### Use Case 3: Logistics System
**Legacy System**: Logistics database with unit locations, supply levels, movement plans.

**Current Problem**: Contractor with limited clearance sees sensitive unit locations.

**DCS Solution**:
- System identifies sensitive fields (unit locations, movement plans)
- Labels fields with appropriate classification
- Contractor queries supply levels (authorized)
- System shows supply data, redacts location fields
- Contractor sees "[REDACTED]" for location fields
- Audit log records field-level filtering

## Out of Scope

- Rewriting legacy applications
- Replacing existing authentication systems
- Real-time streaming data classification
- Classification of data in motion (network traffic)
- Encryption of data at rest (separate concern)
- Cross-domain solutions (separate scenario)
- AI/ML model training (assume pre-trained models available)

## Related Scenarios

- **Scenario 01**: Strategic sharing - DCS for new data being shared
- **Scenario 02**: Tactical operations - DCS in disconnected environments
- **Scenario 03**: This scenario - DCS retrofit for legacy systems

This scenario focuses on retrofitting DCS onto existing systems. For new systems, design DCS in from the start (Scenarios 01 and 02).

## Key Assumptions

1. **Content is Analyzable**: Legacy data is in formats that can be parsed and analyzed
2. **Labeling Rules Exist**: Organization has defined rules for classifying content
3. **User Attributes Available**: User clearances and permissions are in accessible directory
4. **Performance Acceptable**: Minimal added latency is acceptable to users for security benefits
5. **Accuracy Sufficient**: Very high classification accuracy meets security requirements
6. **Manual Review Available**: Misclassified content can be manually corrected

## Risk Considerations

**Security Risks**:
- Under-classification (false negative) exposes sensitive data
- Over-classification (false positive) reduces operational effectiveness
- DCS layer bypass could expose all data
- Audit log tampering could hide security incidents

**Operational Risks**:
- Performance degradation impacts user productivity
- Misclassification causes user frustration
- System complexity increases maintenance burden
- Integration failures could break legacy application

**Mitigation Strategies**:
- Bias toward over-classification (fail secure)
- Extensive testing before deployment
- Manual review process for critical content
- Graceful degradation if DCS layer fails
- Comprehensive monitoring and alerting

---

*This scenario addresses the critical challenge of applying modern data-centric security principles to legacy systems that were not designed with DCS in mind.*
