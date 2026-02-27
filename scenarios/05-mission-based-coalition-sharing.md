# Scenario 05: Mission-Based Coalition Data Sharing

## Overview

Military coalitions form for specific operations (counter-piracy, humanitarian assistance, peacekeeping, counter-terrorism) with defined start and end dates. Data sharing during these missions must be tightly scoped to mission participants and automatically expire when the mission concludes. This scenario explores time-limited, mission-specific data sharing that enables effective coalition operations whilst protecting national interests and preventing data persistence beyond mission requirements.

## Problem Statement

Current coalition data sharing often uses static access controls that don't automatically expire. Data shared for a specific mission remains accessible indefinitely, creating security risks and compliance issues. Nations need the ability to share data for a mission's duration, with automatic access revocation when the mission ends, whilst maintaining audit trails for accountability.

## Actors

### Lead Nation
- **Role**: Mission command authority
- **Responsibilities**: Define mission scope, duration, participants
- **Data Contribution**: Operational plans, intelligence, logistics coordination

### Contributing Nations (3-5 nations)
- **Role**: Mission participants
- **Responsibilities**: Contribute forces and intelligence
- **Data Contribution**: National intelligence, force status, sensor data
- **Constraints**: Each nation has different sharing restrictions

### Mission Partners (NGOs, International Organisations)
- **Role**: Humanitarian or civilian coordination
- **Responsibilities**: Provide situational awareness, coordinate civilian activities
- **Data Contribution**: Humanitarian situation reports, civilian infrastructure status
- **Constraints**: Cannot access military operational details

### Non-Participants
- **Role**: Nations not involved in this specific mission
- **Status**: Should have no access to mission data, even if allied

## Scenario Flow

### Phase 1: Mission Establishment

**Context**: UN Security Council authorises peacekeeping mission in fictional country "Northland". Mission duration: 6 months. Participants: UK (lead), France, Germany, Poland, Canada.

**Action**: Lead nation establishes mission data sharing framework.

**Requirements**:
- Create mission identifier: "OPERATION NORTHERN GUARDIAN"
- Define mission duration: 1 March 2026 - 31 August 2026
- Specify participants: UK, FR, DE, PL, CA
- Define data classification levels for mission
- Establish access policies per nation

**Data Labelling**:
```
Mission: OPERATION NORTHERN GUARDIAN
Duration: 2026-03-01 to 2026-08-31
Participants: UK, FR, DE, PL, CA
Classification: NATO SECRET
Releasability: Mission participants only
Auto-expire: 2026-08-31 23:59:59 UTC
```

### Phase 2: Intelligence Sharing During Mission

**Context**: UK intelligence identifies threat to peacekeepers. Needs to share with mission participants but not other allies.

**UK Intelligence Report**:
- Classification: UK SECRET
- Mission: OPERATION NORTHERN GUARDIAN
- Releasability: Mission participants (UK, FR, DE, PL, CA)
- Expiry: Mission end date (31 Aug 2026)
- Content: Threat assessment, recommended force protection measures

**Access Control**:
- ✅ French peacekeeper commander (mission participant) → Full access
- ✅ German logistics officer (mission participant) → Full access
- ❌ US intelligence analyst (not mission participant, even though ally) → No access
- ❌ UK analyst not assigned to mission → No access (need-to-know)
- ✅ Canadian force protection officer (mission participant) → Full access

### Phase 3: Dynamic Participant Changes

**Context**: 1 May 2026 - Italy joins mission. 1 June 2026 - Poland withdraws forces.

**Italy Joins (1 May 2026)**:
- Italy added to mission participant list
- Italian personnel immediately gain access to mission data
- Historical mission data (from 1 March) accessible to Italy
- Italy can contribute data to mission

**Poland Withdraws (1 June 2026)**:
- Polish personnel lose access to new mission data
- Polish access to historical data (1 March - 1 June) retained for accountability
- Polish-contributed data remains accessible to other participants
- Polish audit logs preserved

### Phase 4: Mission Extension

**Context**: 15 August 2026 - Mission extended by 3 months to 30 November 2026.

**Extension Process**:
- Lead nation updates mission end date
- All mission data automatically inherits new expiry date
- Participants notified of extension
- Access continues seamlessly
- Audit trail records extension decision

### Phase 5: Mission Conclusion

**Context**: 30 November 2026 - Mission concludes successfully.

**Automatic Actions at Mission End**:
- All mission participant access automatically revoked (1 December 2026 00:00:00 UTC)
- Mission data remains encrypted and inaccessible
- Audit logs preserved for compliance and lessons learned
- Data marked for archival or deletion per retention policies
- Participants cannot access mission data even if they have valid clearances

**Post-Mission Access**:
- Historical access for lessons learned (requires special authorisation)
- Audit review for compliance investigations
- Archival access for historians (after declassification period)

## Operational Constraints

1. **Time-Limited Access**: Access must automatically expire at mission end
2. **Dynamic Membership**: Support adding/removing participants during mission
3. **Need-to-Know**: Mission participation alone insufficient; role-based access within mission
4. **National Caveats**: Each nation can impose additional restrictions on their contributions
5. **Audit Requirements**: Complete audit trail for accountability
6. **Mission Isolation**: Data from different missions must not cross-contaminate
7. **Graceful Degradation**: System continues if one nation's infrastructure unavailable
8. **Post-Mission Accountability**: Audit logs accessible after mission ends

## Technical Challenges

1. **Time-Based Access Control**: How to enforce automatic expiry at mission end?
2. **Dynamic Participant Management**: How to add/remove participants without re-encrypting data?
3. **Mission Scoping**: How to prevent mission data leaking to non-participants?
4. **National Caveats**: How to layer national restrictions on top of mission access?
5. **Clock Synchronisation**: How to ensure consistent time-based expiry across nations?
6. **Mission Extension**: How to update expiry dates on already-shared data?
7. **Audit Preservation**: How to maintain audit logs after access expires?
8. **Graceful Expiry**: How to handle users with open documents when mission expires?

## Acceptance Criteria

### AC1: Mission-Scoped Access Control
- [ ] Data labelled with mission identifier
- [ ] Only mission participants can access mission data
- [ ] Non-participants denied access even if allied
- [ ] Personnel not assigned to mission denied access (need-to-know)
- [ ] Access decisions based on mission membership, clearance, and role

### AC2: Time-Limited Access
- [ ] Data labelled with mission start and end dates
- [ ] Access automatically granted at mission start
- [ ] Access automatically revoked at mission end
- [ ] Expiry enforced consistently across all nations
- [ ] Grace period for users with open documents (configurable)
- [ ] Clear user notification before expiry

### AC3: Dynamic Participant Management
- [ ] New participants can be added during mission
- [ ] New participants gain access to historical mission data
- [ ] Departing participants lose access to new data
- [ ] Departing participants retain access to historical data for accountability
- [ ] Participant changes logged in audit trail
- [ ] No need to re-encrypt data when participants change

### AC4: Mission Extension
- [ ] Mission end date can be updated
- [ ] All mission data inherits new expiry date
- [ ] Extension applies to already-shared data
- [ ] Participants notified of extension
- [ ] Extension decision logged in audit trail

### AC5: National Caveats
- [ ] Nations can impose additional restrictions on their contributions
- [ ] National caveats layer on top of mission access policies
- [ ] Example: UK data marked "UK EYES ONLY" within mission
- [ ] Example: French data marked "NO FURTHER DISSEMINATION"
- [ ] Caveats enforced consistently across mission

### AC6: Mission Isolation
- [ ] Data from different missions kept separate
- [ ] Personnel in Mission A cannot access Mission B data
- [ ] Same person in multiple missions sees only relevant data per mission
- [ ] Mission identifiers prevent cross-contamination

### AC7: Comprehensive Audit Trail
- [ ] All access attempts logged (successful and denied)
- [ ] Logs include: user, mission, timestamp, data accessed, decision
- [ ] Participant changes logged
- [ ] Mission extensions logged
- [ ] Audit logs preserved after mission ends
- [ ] Audit logs accessible for compliance and lessons learned

### AC8: Post-Mission Data Management
- [ ] Data inaccessible after mission end (unless special authorisation)
- [ ] Data marked for archival or deletion per retention policy
- [ ] Audit logs preserved for compliance period
- [ ] Special access for lessons learned (with authorisation)
- [ ] Declassification process for historical access

### AC9: Federated Infrastructure
- [ ] Each nation operates independent key management
- [ ] Mission access works if one nation's infrastructure unavailable
- [ ] No central authority required for access decisions
- [ ] Each nation maintains sovereignty over their data

### AC10: User Experience
- [ ] Users see only missions they're assigned to
- [ ] Clear indication of mission context when accessing data
- [ ] Warnings before mission expiry
- [ ] Graceful handling of expiry (save work, close documents)
- [ ] Clear error messages when access denied

## Success Metrics

- **Access Accuracy**: All and only mission participants can access mission data
- **Expiry Enforcement**: Access automatically revoked at mission end
- **Participant Changes**: Adding/removing participants works seamlessly
- **Audit Completeness**: All access attempts logged
- **Mission Isolation**: No cross-contamination between missions
- **User Satisfaction**: Personnel find mission-based sharing intuitive
- **Compliance**: Meets data retention and audit requirements

## Example Use Cases

### Use Case 1: Counter-Piracy Operation
**Mission**: OPERATION OCEAN SHIELD (6 months)
**Participants**: UK, France, Italy, Spain (naval forces)
**Data**: Ship locations, piracy incidents, patrol schedules
**Expiry**: Automatic at mission end
**Extension**: Extended twice due to ongoing piracy threat

### Use Case 2: Humanitarian Assistance
**Mission**: OPERATION HELPING HAND (3 months)
**Participants**: Germany, Netherlands, Poland, UN agencies, Red Cross
**Data**: Disaster assessment, aid distribution, infrastructure status
**Mixed Classification**: Military logistics (SECRET), humanitarian data (UNCLASSIFIED)
**Expiry**: Automatic at mission end, but humanitarian data archived for future disasters

### Use Case 3: Training Exercise
**Mission**: EXERCISE NORTHERN STRIKE (2 weeks)
**Participants**: UK, US, Norway, Sweden
**Data**: Exercise plans, simulated intelligence, after-action reports
**Expiry**: Automatic 30 days after exercise end
**Lessons Learned**: Special access granted for 1 year for training development

## Out of Scope

- Real-time tactical communications (separate system)
- Long-term strategic intelligence sharing (covered in Scenario 01)
- Cross-domain transfers (covered in Scenario 04)
- Legacy system integration (covered in Scenario 03)

## Related Scenarios

- **Scenario 01**: Coalition strategic sharing - long-term relationships
- **Scenario 07**: Intelligence fusion centres - persistent multi-national facilities
- **Scenario 08**: Coalition air operations - real-time mission coordination

## Key Assumptions

1. **Mission Definition**: Missions have clear start/end dates and participant lists
2. **Time Synchronisation**: Nations can synchronise clocks for consistent expiry
3. **Participant Authority**: Lead nation has authority to define mission scope
4. **Audit Requirements**: All nations agree to preserve audit logs
5. **Graceful Expiry**: Short grace period acceptable for users to save work

## Risk Considerations

**Security Risks**:
- Mission data accessed after expiry due to clock skew
- Participant list manipulation to grant unauthorised access
- Mission extensions used to indefinitely extend access
- Audit logs deleted to hide unauthorised access

**Operational Risks**:
- Premature expiry disrupts ongoing operations
- Participant removal disrupts coordination
- Mission extensions not communicated to all participants
- Users lose access mid-task when mission expires

**Mitigation Strategies**:
- Clock synchronisation protocols (NTP, GPS time)
- Mission definition requires multi-party authorisation
- Mission extensions require justification and approval
- Audit logs tamper-proof and replicated
- Grace period for expiry (e.g., 1 hour warning)
- Clear user notifications and documentation

---

*This scenario enables agile coalition formation and dissolution whilst maintaining security and accountability. Time-limited, mission-scoped access ensures data sharing is appropriate to operational needs without creating long-term security liabilities.*
