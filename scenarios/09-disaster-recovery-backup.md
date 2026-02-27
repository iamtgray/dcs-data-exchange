# Scenario 09: Disaster Recovery and Backup with Data-Centric Security

## Overview

Military organisations must backup classified data for disaster recovery, but backups themselves are high-value targets. Backup media must be stored securely, potentially off-site or with third-party providers, whilst maintaining the same access controls as the original data. When restoring from backup, the system must enforce the same policies that applied to the original data, even if years have passed. The challenge is maintaining data-centric security through the entire backup and restore lifecycle whilst meeting recovery time objectives.

## Problem Statement

Current backup systems often treat all data at the same classification level, creating over-classification (everything backed up at highest level) or under-protection (sensitive data backed up with insufficient controls). Backup media is difficult to track and manage, especially when stored off-site. Restoration often bypasses access controls, allowing anyone with physical access to backup media to restore and access data. Data-centric security must persist through backup, storage, and restoration to maintain protection throughout the data lifecycle.

## Actors

### Data Owners
- **Role**: Create and classify data
- **Responsibilities**: Define access policies, retention periods
- **Data Types**: Intelligence reports, operational plans, personnel records, logistics data

### Backup Administrators
- **Role**: Manage backup systems and media
- **Responsibilities**: Schedule backups, manage media, perform restorations
- **Constraints**: Should not have access to backed-up data content

### Backup Storage Providers
- **Role**: Store backup media (on-site, off-site, cloud)
- **Types**: Military facilities, commercial providers, cloud services
- **Constraints**: Should not have access to backed-up data content

### Restoration Requestors
- **Role**: Request data restoration after disaster or data loss
- **Responsibilities**: Justify restoration need
- **Constraints**: Must have same access rights as original data

### Compliance Officers
- **Role**: Ensure backup and retention policies followed
- **Responsibilities**: Audit backups, enforce retention periods
- **Constraints**: May need to verify backups without accessing content

## Scenario Flow

### Phase 1: Data Creation and Classification

**Context**: Intelligence analyst creates report with mixed sensitivity.

**Original Data**:
```
Document: OPERATION WALL Intelligence Assessment
Classification: TOP SECRET//SI
Author: UK Intelligence Analyst
Created: 15 January 2026
Access Policy:
  - Clearance: TS/SCI required
  - Nationality: UK, US only
  - Role: Intelligence analyst or commander
  - Retention: 10 years
  - Backup: Required (encrypted)
```

### Phase 2: Automated Backup

**Context**: Nightly backup runs, capturing all data created/modified that day.

**Backup Process**:
1. Backup system identifies data for backup
2. Data already encrypted with DCS (TDF/ZTDF)
3. Backup system copies encrypted data without decrypting
4. Backup inherits all access policies from original data
5. Backup media encrypted with additional layer (backup encryption key)
6. Backup metadata created

**Backup Metadata**:
```
Backup ID: BACKUP-2026-01-15-001
Date: 15 January 2026
Contents: 1,247 files
Classifications: UNCLASSIFIED (45%), SECRET (40%), TOP SECRET (15%)
Total Size: 2.3 TB
Media: Tape LTO-9 Serial #12345
Location: On-site secure storage
Encryption: AES-256 (backup key) + DCS (per-file policies)
Retention: Longest file retention period (10 years)
```

**Access Control**:
- ✅ Backup administrator can manage backup media
- ❌ Backup administrator cannot access backed-up data content
- ✅ Backup system can read encrypted data for backup
- ❌ Backup system cannot decrypt data content

### Phase 3: Off-Site Storage

**Context**: Backup media transported to off-site facility for disaster recovery.

**Transport Process**:
1. Backup media sealed in tamper-evident container
2. Transported by secure courier
3. Stored in off-site facility (military or commercial)
4. Facility has physical security but not clearances for data content

**Off-Site Storage Metadata**:
```
Media: Tape LTO-9 Serial #12345
Location: Off-Site Facility BRAVO
Arrival: 16 January 2026
Container: Sealed, tamper-evident
Access Log: Physical access logged, no content access
Retrieval Time: 4 hours (if needed)
```

**Access Control**:
- ✅ Off-site facility can store media physically
- ❌ Off-site facility cannot access data content
- ✅ Off-site facility logs physical access to media
- ❌ Off-site facility personnel do not have clearances for data

### Phase 4: Disaster Recovery Restoration

**Context**: Primary data centre destroyed in disaster. Must restore from off-site backup.

**Restoration Request**:
```
Requestor: UK Intelligence Commander
Justification: Primary data centre destroyed, need operational data
Backup: BACKUP-2026-01-15-001
Priority: High
Clearance: TS/SCI
Nationality: UK
```

**Restoration Process**:
1. Off-site facility retrieves backup media (4 hours)
2. Media transported to recovery site
3. Backup system decrypts backup media (backup encryption key)
4. Individual files remain encrypted with DCS
5. Files restored to recovery site storage
6. Users access files based on original access policies
7. Access policies enforced as if data never left primary site

**Access Control During Restoration**:
- ✅ Backup administrator can restore encrypted files
- ❌ Backup administrator cannot access file content
- ✅ UK Intelligence Commander can access TS/SCI UK/US files
- ❌ UK Intelligence Commander cannot access US EYES ONLY files
- ✅ Original access policies enforced on restored data
- ✅ Audit trail shows restoration event

### Phase 5: Selective Restoration

**Context**: Single file accidentally deleted. Need to restore just that file.

**Restoration Request**:
```
Requestor: UK Intelligence Analyst
Justification: Accidentally deleted working document
File: OPERATION WALL Intelligence Assessment
Backup: BACKUP-2026-01-15-001
Priority: Medium
Clearance: TS/SCI
Nationality: UK
```

**Selective Restoration Process**:
1. Backup system locates file in backup
2. Verifies requestor has access rights to original file
3. Restores single file (not entire backup)
4. File access policy enforced immediately
5. Audit trail shows selective restoration

**Access Control**:
- ✅ Analyst can restore file they originally had access to
- ❌ Analyst cannot restore files they don't have access to
- ✅ Backup system verifies access rights before restoration
- ❌ Backup administrator cannot override access policies

### Phase 6: Retention and Deletion

**Context**: Data retention period expires. Data must be deleted from backups.

**Retention Policy**:
```
Document: OPERATION WALL Intelligence Assessment
Retention Period: 10 years
Created: 15 January 2026
Expiry: 15 January 2036
Action: Delete from all backups after expiry
```

**Deletion Process**:
1. Retention system identifies expired data
2. Marks data for deletion in all backups
3. Next backup cycle excludes expired data
4. Old backup media with expired data marked for destruction
5. Audit trail records deletion

**Compliance Verification**:
- ✅ Compliance officer can verify retention policies followed
- ✅ Compliance officer can see backup metadata
- ❌ Compliance officer cannot access data content (unless authorised)
- ✅ Audit trail shows data deleted per retention policy

## Operational Constraints

1. **Backup Performance**: Backups must complete within backup window (overnight)
2. **Recovery Time Objective (RTO)**: Restore critical data within hours
3. **Recovery Point Objective (RPO)**: Lose no more than 24 hours of data
4. **Access Control**: Backup administrators cannot access data content
5. **Off-Site Storage**: Backup media stored off-site for disaster recovery
6. **Retention Compliance**: Data deleted per retention policies
7. **Audit Requirements**: All backup, restoration, and deletion logged
8. **Encryption**: Backup media encrypted for transport and storage

## Technical Challenges

1. **Policy Persistence**: How to maintain access policies through backup and restore?
2. **Backup Encryption**: How to encrypt backups without decrypting DCS-protected data?
3. **Selective Restoration**: How to restore individual files whilst enforcing access policies?
4. **Retention Management**: How to delete expired data from backups?
5. **Off-Site Security**: How to protect backup media at off-site facilities?
6. **Compliance Verification**: How to verify backups without accessing content?
7. **Performance**: How to backup large volumes without impacting operations?
8. **Key Management**: How to manage backup encryption keys separately from DCS keys?

## Acceptance Criteria

### AC1: Policy Persistence
- [ ] Backed-up data retains all access policies from original
- [ ] Restored data enforces same policies as original
- [ ] Policies enforced even years after backup
- [ ] No policy degradation through backup/restore cycle

### AC2: Backup Administrator Separation
- [ ] Backup administrators can manage backup systems
- [ ] Backup administrators can manage backup media
- [ ] Backup administrators cannot access data content
- [ ] Backup administrators cannot override access policies
- [ ] Separation enforced technically, not just procedurally

### AC3: Encrypted Backup
- [ ] Backup media encrypted for transport and storage
- [ ] Backup encryption separate from DCS encryption (defence in depth)
- [ ] Backup encryption keys managed separately
- [ ] Off-site facilities cannot decrypt backup media
- [ ] Lost/stolen backup media remains protected

### AC4: Selective Restoration
- [ ] Individual files can be restored without full backup restoration
- [ ] Requestor access rights verified before restoration
- [ ] Only authorised files restored to requestor
- [ ] Restoration logged in audit trail
- [ ] Restoration performance acceptable (minutes for single file)

### AC5: Off-Site Storage
- [ ] Backup media can be stored at off-site facilities
- [ ] Off-site facilities do not need clearances for data content
- [ ] Physical access to media logged
- [ ] Media retrieval time meets RTO requirements
- [ ] Transport security maintained

### AC6: Retention Management
- [ ] Data retention periods tracked through backups
- [ ] Expired data automatically deleted from backups
- [ ] Old backup media marked for destruction when all data expired
- [ ] Retention policy compliance verifiable
- [ ] Deletion logged in audit trail

### AC7: Compliance Verification
- [ ] Compliance officers can verify backups exist
- [ ] Compliance officers can verify retention policies followed
- [ ] Compliance officers can see backup metadata
- [ ] Compliance officers cannot access data content (unless separately authorised)
- [ ] Audit trails support compliance investigations

### AC8: Disaster Recovery
- [ ] Full system restoration possible from off-site backups
- [ ] RTO met for critical data (hours)
- [ ] RPO met (no more than 24 hours data loss)
- [ ] Access policies enforced immediately after restoration
- [ ] Audit trail continuous through disaster and recovery

### AC9: Performance
- [ ] Backups complete within backup window
- [ ] Minimal impact on operational systems
- [ ] Restoration performance meets RTO
- [ ] Scales to organisational data volumes
- [ ] Incremental backups for efficiency

### AC10: Audit Trail
- [ ] All backups logged
- [ ] All restorations logged (full and selective)
- [ ] All deletions logged
- [ ] Physical access to backup media logged
- [ ] Audit logs tamper-proof and retained per compliance requirements

## Success Metrics

- **Backup Completeness**: All data backed up per schedule
- **RTO Achievement**: Critical data restored within hours
- **RPO Achievement**: No more than 24 hours data loss
- **Access Control**: Backup administrators cannot access data content
- **Retention Compliance**: Expired data deleted per policy
- **Audit Completeness**: All backup/restore/delete operations logged
- **Security**: No unauthorised access to backup media or content

## Example Use Cases

### Use Case 1: Nightly Backup
**Data**: Mixed classification (UNCLASS to TOP SECRET)
**Process**: Automated backup of all data
**Encryption**: DCS per-file + backup media encryption
**Storage**: On-site secure storage + off-site facility

### Use Case 2: Disaster Recovery
**Scenario**: Data centre destroyed
**Process**: Full restoration from off-site backup
**Timeline**: 4 hours to retrieve media, 8 hours to restore critical data
**Access Control**: Original policies enforced on restored data

### Use Case 3: Accidental Deletion
**Scenario**: User accidentally deletes important file
**Process**: Selective restoration of single file
**Timeline**: 30 minutes to restore
**Access Control**: User must have original access rights

### Use Case 4: Compliance Audit
**Scenario**: Verify retention policies followed
**Process**: Compliance officer reviews backup metadata and audit logs
**Access**: Metadata only, not data content
**Result**: Confirm expired data deleted per policy

## Out of Scope

- Real-time replication (separate from backup)
- Database-specific backup strategies
- Application-level backup (focus on file-level)
- Backup of data in motion (network traffic)

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing - data policies persist through sharing
- **Scenario 03**: Legacy system retrofit - applying DCS to existing data
- **Scenario 04**: Cross-domain sanitisation - retention and declassification

## Key Assumptions

1. **DCS Implementation**: Data already protected with DCS (TDF/ZTDF)
2. **Backup Infrastructure**: Backup systems can handle encrypted data
3. **Key Management**: Backup encryption keys managed separately from DCS keys
4. **Off-Site Facilities**: Trusted facilities available for off-site storage
5. **Retention Policies**: Data owners define retention periods

## Risk Considerations

**Security Risks**:
- Backup media lost or stolen during transport
- Off-site facility compromised
- Backup administrator abuses access to restore unauthorised data
- Backup encryption keys compromised
- Expired data not deleted, creating compliance risk

**Operational Risks**:
- Backup window insufficient for data volumes
- RTO not met during disaster recovery
- Selective restoration too slow for operational needs
- Retention management too complex, leading to errors
- Backup media degradation over time

**Mitigation Strategies**:
- Defence in depth: DCS encryption + backup encryption
- Tamper-evident containers for transport
- Access control verification before restoration
- Separate key management for backup and DCS
- Regular backup testing and restoration drills
- Automated retention management
- Media integrity verification

---

*This scenario ensures data-centric security persists through the entire backup and restore lifecycle, maintaining protection whilst enabling disaster recovery and compliance with retention policies.*
