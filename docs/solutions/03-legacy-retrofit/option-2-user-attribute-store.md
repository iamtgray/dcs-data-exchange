# Option 2: User Attribute Store (DCS Level 2 prerequisite)

## Solution overview

This solution builds a user attribute store that enriches RACF identity information with the security attributes needed for data-centric access control: NATO clearance level, national caveats, SAP memberships, releasability, and role-based need-to-know. Without this, the TN3270 proxy (Option 3) knows who the user is but not what they're allowed to see.

## Scenario reference

**Addresses**: Scenario 03 -- Legacy System DCS Retrofit
**DCS Level**: Level 2 prerequisite (Attribute-Based Access Control)
**Dependency**: None (can be built in parallel with Option 1)
**Dependents**: Option 3 (TN3270 proxy) requires this to make filtering decisions

## The problem

RACF on the JLTS mainframe knows three things about each user:

1. Their user ID (e.g., `JDUPON01`)
2. Which RACF group they belong to (`JLTS-USER`, `JLTS-ADMIN`, or `JLTS-BATCH`)
3. Whether their password is valid

RACF does not know:
- That `JDUPON01` is a French national
- That they hold NATO CONFIDENTIAL clearance (not SECRET)
- That they are not read into any SAPs
- That they should only see data marked `REL_TO:FRA` or `REL_TO:NATO`
- That their role is "liaison officer" with need-to-know limited to French national contributions and general logistics

This gap is fundamental. You can label every record in JLTS perfectly (Option 1), but if the enforcement layer can't evaluate "is this user cleared to see NATO SECRET data?", the labels are useless.

## How it works

### Attribute schema

Each JLTS user is mapped to a set of security attributes:

| Attribute | Description | Example Values |
|---|---|---|
| `RACF_ID` | RACF user ID (primary key) | `JDUPON01` |
| `NATIONALITY` | ISO 3166-1 alpha-3 country code | `FRA`, `GBR`, `USA` |
| `CLEARANCE_LEVEL` | NATO clearance level | `NU`, `NR`, `NC`, `NS`, `CTS` |
| `SAP_MEMBERSHIPS` | List of SAP/compartment access | `WALL`, `GRIFFIN`, or empty |
| `RELEASABILITY` | What releasability markings the user can access | `REL_TO:NATO`, `REL_TO:FRA,GBR` |
| `ROLE` | Operational role for need-to-know | `LOGISTICS_OFFICER`, `LIAISON`, `PROCUREMENT`, `AUDITOR`, `ADMIN` |
| `ORGANISATION` | Organisational unit | `NSPA`, `SHAPE`, `FRA-LIAISON`, `GBR-LOG-BDE` |
| `VALID_FROM` | Attribute validity start date | `2025-01-15` |
| `VALID_TO` | Attribute validity end date | `2026-12-31` |
| `LAST_VERIFIED` | Date attributes were last verified by national authority | `2026-02-01` |
| `VERIFIED_BY` | Who verified the attributes | `FRA-SEC-OFFICER` |

### Where to store it

There are three viable options for where the attribute store lives:

**Option A: DB2 table on the mainframe**

A new table in the `JLTS_DCS` schema alongside the shadow label tables. The TN3270 proxy queries it via DB2 SQL.

- Advantage: co-located with the label store, simple architecture, no additional infrastructure
- Disadvantage: another thing on the mainframe, requires mainframe DB2 access from the proxy

**Option B: LDAP directory extension**

Several NATO nations already use LDAP or Active Directory for user management. Extend the existing directory schema with custom attributes for clearance, nationality, and SAPs. The proxy queries LDAP at session establishment.

- Advantage: leverages existing identity infrastructure, attributes managed by national security officers through familiar tools
- Disadvantage: requires schema extensions to LDAP, may need federation across national directories, LDAP schema changes can be politically difficult

**Option C: External attribute service**

A lightweight REST service backed by a modern database (PostgreSQL, etc.) running off-mainframe. The proxy calls the service to look up user attributes.

- Advantage: modern tooling, easy to build management UI, decoupled from mainframe
- Disadvantage: additional infrastructure to deploy and secure within the NATO SECRET domain, network dependency

**Recommendation**: Option A (DB2 table) for initial deployment, with a migration path to Option B (LDAP) as the organisation matures its identity management. The DB2 table is the fastest to implement and keeps the architecture simple. LDAP integration is the long-term answer but involves more stakeholders and longer timelines.

### Population and maintenance

The attribute store is only as good as its data. Stale or incorrect attributes are a security risk (user sees data they shouldn't) or an operational risk (user can't see data they need).

**Initial population**:
1. Export the RACF user list (~850 active accounts)
2. Cross-reference with the NATO personnel database or national security officer records to determine nationality, clearance, and SAPs for each user
3. Assign roles based on RACF group membership and organisational knowledge
4. Load into the attribute store
5. Have each national security officer verify their nation's users

This is a manual, human-driven process. It cannot be automated because the source data (clearance levels, SAP memberships) is held by national security authorities, not in any system JLTS can query.

**Ongoing maintenance**:
- National security officers update attributes when clearances change (promotion, revocation, expiry)
- A management interface (web form or batch upload) allows authorised personnel to update attributes
- Attributes have validity dates (`VALID_FROM`, `VALID_TO`) -- expired attributes trigger re-verification
- Quarterly verification cycle: each national security officer confirms their users' attributes are current
- Audit log of all attribute changes (who changed what, when, why)

**Edge cases**:
- New JLTS user created in RACF but not yet in attribute store → proxy defaults to most restrictive access (UNCLASSIFIED only) until attributes are populated
- User's clearance downgraded → national security officer updates attribute store, proxy immediately enforces new level
- User leaves organisation → RACF account disabled (existing process), attribute store record marked inactive

### Attribute caching

The proxy needs to look up user attributes on every screen render. To avoid per-screen-load latency:

- Attributes are cached by the proxy at session establishment (TN3270 login)
- Cache TTL is configurable (recommended: 1 hour for interactive sessions)
- Cache is invalidated if the attribute store signals a change (or on next session if push notification isn't feasible)
- Batch processing uses the service account's attributes (which have broad access by design)

## Advantages

1. **Enables ABAC**: Provides the user-side attributes needed for attribute-based access control decisions
2. **Decoupled from RACF**: Doesn't require modifying RACF configuration or mainframe security settings
3. **Auditable**: Full change history of who had what attributes and when
4. **Verifiable**: National security officers can verify and attest to their users' attributes
5. **Temporal**: Validity dates ensure attributes don't go stale silently
6. **Reusable**: The same attribute store can serve the proxy (Option 3), batch gateway (Option 4), and any future DCS components

## Disadvantages

1. **Manual population**: Initial load requires coordination with 14 national security officers -- this is a people problem, not a technology problem
2. **Synchronisation risk**: If a user's clearance is revoked in the national system but the attribute store isn't updated, the user retains access
3. **No authoritative source**: The attribute store is a copy of information held by national authorities, not the authoritative source -- it can drift
4. **Maintenance overhead**: Quarterly verification across 14 nations is an ongoing administrative burden
5. **Single point of failure**: If the attribute store is unavailable, the proxy can't make access decisions (mitigated by caching)

## Acceptance criteria coverage

From Scenario 03:

- ✅ **AC2: User Attribute Integration** -- Retrieves clearance, SAPs, nationality, and role
- ✅ **AC2: Integration with LDAP, AD, PKI** -- Can integrate with existing directories (Option B) or operate independently (Option A)
- ✅ **AC2: User attributes cached** -- Caching at session establishment with configurable TTL
- ✅ **AC3: Policy-Based Access Control** -- Provides user-side attributes for policy evaluation (enforcement is in Option 3)
- ✅ **AC10: Policy Management** -- Attribute changes take effect within cache TTL

## Technology stack

- IBM DB2 for z/OS (Option A) or LDAP/AD (Option B) or PostgreSQL + REST API (Option C)
- Management interface for national security officers (web form or batch upload)
- Audit logging for all attribute changes
- Cache layer in the TN3270 proxy (Option 3)

## Implementation complexity

**Complexity**: Low (technically), Medium (organisationally)

The technology is straightforward -- it's a lookup table with a management interface. The hard part is the human process: getting 14 national security officers to provide and verify user attributes, establishing the quarterly verification cycle, and defining the governance model for who can update what.

## Operational fit

This is the least glamorous component of the DCS retrofit but arguably the most important after the label store. Without accurate user attributes, the proxy is just a 3270 pass-through. The organisational challenge (coordinating with national security officers) is the primary risk -- the technology is simple.

The recommended approach is to start with a DB2 table populated from a spreadsheet exercise with national security officers, get the proxy working end-to-end, and then invest in LDAP integration and a proper management UI once the value is proven.

---

*Provides user security attributes for ABAC decisions. Technically simple, organisationally challenging. Must be paired with Option 1 (labels) and Option 3 (proxy) for operational benefit.*
