# Scenario 17: Multinational Logistics and Supply Chain Data Sharing

## Overview

NATO logistics is the backbone of alliance defence. Approximately 90% of military transport for large operations is provided by civilian assets, and host nation support underpins reinforcement across NATO's eastern flank. Effective logistics coordination requires sharing supply levels, transport routes, ammunition stocks, maintenance status, and host nation capacity across nations and between military and commercial providers. However, logistics data is aggregation-sensitive: individual supply items are unclassified, but the combined force readiness picture is classified. This scenario explores data-centric security for logistics data that must flow between military headquarters, national logistics commands, commercial transport providers, and host nation authorities.

## Problem Statement

NATO's 2024 Logistics Action Plan and 2023 Logistics Manifesto acknowledge that "NATO commanders require timely, accurate and relevant information" for logistics, but current sharing mechanisms cannot handle the aggregation sensitivity of logistics data or the military-commercial data boundary. A single ammunition stock report is RESTRICTED; the combined ammunition availability across all NATO nations on the eastern flank is SECRET or above because it reveals alliance combat sustainability. Commercial transport providers need route data and cargo dimensions but must not see what they are transporting or why. Host nation support authorities need to know what facilities are required but not the operational plans they support.

## Actors

### NATO Logistics Commands
- **Role**: Coordinate alliance logistics across operations
- **Types**: SHAPE J4, JFC logistics, component command logistics
- **Data**: Combined force readiness, sustainability assessments, priority allocations
- **Classification**: SECRET to TOP SECRET (aggregated readiness data)

### National Logistics Commands
- **Role**: Manage national force logistics
- **Types**: Each nation's logistics organisation
- **Data**: National stock levels, maintenance status, transport capacity
- **Classification**: National RESTRICTED to SECRET

### Commercial Transport Providers
- **Role**: Provide road, rail, sea, and air transport for military movements
- **Clearances**: None (commercial entities)
- **Data Need**: Route, timing, dimensions, weight (NOT contents or purpose)
- **Constraint**: Cannot access military classification systems

### Host Nation Support Authorities
- **Role**: Provide facilities, infrastructure, and services in transit/destination nations
- **Clearances**: Limited national clearances at most
- **Data Need**: Facility requirements, timings, infrastructure capacity
- **Constraint**: Must not see operational plans that drive logistics requirements

### Military Units (Consumers)
- **Role**: Receive logistics support in the field
- **Data Need**: Supply status, expected delivery times, alternative sources
- **Constraint**: Operate in DDIL environments (see Scenario 02)

## Scenario Flow

### Phase 1: National Logistics Reporting

**Context**: NATO exercise involves rapid reinforcement of eastern flank. 15 nations report logistics status.

**National Reports**:
```
Nation A: Ammunition Report
  Item: 155mm artillery shells
  Quantity: 50,000 rounds
  Location: National depot
  Availability: 30,000 rounds deployable within 48h
  Classification: NATIONAL RESTRICTED
  Releasability: NATO logistics staff

Nation B: Transport Capacity
  Asset: Heavy equipment transporters
  Quantity: 200 vehicles
  Availability: 150 vehicles within 72h
  Location: National bases
  Classification: NATIONAL RESTRICTED
  Releasability: NATO logistics staff + host nation transport authorities
```

**DCS Application**: Each national report wrapped in ZTDF with national classification and NATO releasability. Individual reports accessible to authorised logistics staff.

### Phase 2: Aggregated Readiness Assessment

**Context**: NATO J4 aggregates national reports into a combined logistics readiness assessment.

**Aggregated Assessment**:
```
NATO LOGISTICS READINESS - OPERATION STEADFAST DEFENDER
  Total 155mm ammunition: [AGGREGATED ACROSS 15 NATIONS]
  Total transport capacity: [AGGREGATED]
  Combined sustainability: [X DAYS OF HIGH-INTENSITY OPERATIONS]
  Critical shortfalls: Identified
  Classification: NATO SECRET (aggregation reveals combat sustainability)
  Releasability: NATO senior commanders, logistics planners
```

**DCS Challenge**: The aggregated assessment is at a HIGHER classification than any individual national input. DCS must enforce that personnel with access to multiple national reports cannot produce an unauthorised aggregation. The authorised aggregation (by J4) carries its own higher classification.

**DCS Application**: Aggregated assessment wrapped in ZTDF at NATO SECRET. Individual national inputs remain at RESTRICTED. The aggregation relationship is tracked -- changes to national inputs trigger review of the aggregated assessment. Access to the aggregation requires higher clearance than access to individual inputs.

### Phase 3: Commercial Transport Coordination

**Context**: Military convoys need commercial transport from western depots to eastern deployment areas.

**Data for Commercial Providers**:
```
Movement Request (COMMERCIAL VIEW):
  Origin: Depot location (general area, not exact military facility)
  Destination: Staging area (general area)
  Timing: Departure window (48-hour window, not exact time)
  Cargo: "Heavy equipment, dimensions X x Y x Z, weight W tonnes"
  Quantity: N vehicle loads
  Route Restrictions: Bridges with weight limits, tunnel height limits
  Classification: UNCLASSIFIED (commercial transport data)

Movement Request (MILITARY VIEW):
  Origin: National ammunition depot, Grid Reference [EXACT]
  Destination: Forward ammunition point, Grid Reference [EXACT]
  Timing: Exact departure and arrival times
  Cargo: 155mm ammunition, 5,000 rounds per vehicle
  Quantity: 10 vehicle loads
  Operational Context: Ammunition resupply for [UNIT] before offensive operation
  Classification: NATO SECRET
  Releasability: Military logistics staff only
```

**DCS Application**: Two ZTDF-wrapped views of the same movement -- commercial view (UNCLASSIFIED, accessible to transport provider) and military view (SECRET, accessible to military logistics staff). Both linked in metadata but commercial view cannot be used to access military view.

### Phase 4: Host Nation Support Coordination

**Context**: Transit nation must prepare facilities for military movements.

**Data for Host Nation**:
```
Host Nation Request:
  Facility: Rail loading facility at [LOCATION]
  Timeframe: Available from [DATE] for 5 days
  Capacity: 20 heavy equipment transports per day
  Support: Fuel, water, rest facilities for 200 personnel
  Security: Host nation perimeter security required
  Classification: NATO RESTRICTED
  Releasability: Host nation logistics authority

NOT Shared with Host Nation:
  - Which units are transiting
  - What equipment is being transported
  - Destination of movements
  - Operational plan driving the requirement
  - Combined force movement schedule
```

**DCS Application**: Host nation data wrapped in ZTDF with RESTRICTED classification and host-nation-accessible ABAC policy. Operational context in a separate ZTDF envelope at SECRET, inaccessible to host nation authorities.

### Phase 5: Forward Logistics in DDIL

**Context**: Deployed units need logistics status updates but have intermittent connectivity.

**Field Unit View**:
```
Unit Logistics Status:
  Ammunition: 3 days supply at current consumption rate
  Fuel: 2 days supply
  Rations: 5 days supply
  Next Resupply: Expected in 36 hours (convoy en route)
  Alternative: Emergency air resupply available if requested
  Classification: SECRET
  Releasability: Unit commander and logistics officer
```

**DCS Application**: Logistics status wrapped in ZTDF, cached on unit's tactical systems for DDIL access. Pre-positioned keys enable decryption without KAS connectivity. Updates synced when connectivity restored.

## Operational Constraints

1. **Aggregation Sensitivity**: Combined data higher classification than individual inputs
2. **Commercial Partners**: Transport providers need data without military clearances
3. **Host Nation Coordination**: Facilities support without operational context
4. **DDIL Forward**: Logistics data must reach deployed units in degraded connectivity
5. **Multi-National**: 15+ nations reporting logistics status
6. **Time Pressure**: Rapid reinforcement requires fast logistics coordination
7. **Civilian Assets**: 90% of transport is civilian-provided

## Technical Challenges

1. **Aggregation Control**: How to prevent unauthorised aggregation of individually lower-classified data?
2. **Dual-View Data**: How to maintain linked military and commercial views of the same movement?
3. **Non-Cleared Access**: How to provide data to commercial and host nation partners?
4. **Dynamic Classification**: How to handle data that changes classification when aggregated?
5. **DDIL Logistics**: How to provide logistics status to deployed units in degraded connectivity?
6. **Scale**: How to handle logistics data from 15+ nations with thousands of line items?

## Acceptance Criteria

### AC1: Aggregation Security
- [ ] Individual national reports accessible at national classification
- [ ] Aggregated assessment automatically classified at higher level
- [ ] Unauthorised aggregation prevented (access to inputs doesn't grant aggregation)
- [ ] Authorised aggregation (J4) tracked with audit trail

### AC2: Commercial Partner Access
- [ ] Transport providers see movement data without military context
- [ ] Commercial view linked to but separate from military view
- [ ] No military classification visible to commercial partners
- [ ] Commercial access audit logged

### AC3: Host Nation Coordination
- [ ] Host nation authorities see facility requirements
- [ ] Operational context (units, plans) not visible to host nation
- [ ] Host nation access governed by ABAC policies
- [ ] Coordination data time-limited to movement window

### AC4: Forward DDIL Logistics
- [ ] Logistics status available to deployed units in degraded connectivity
- [ ] Pre-positioned keys enable offline access
- [ ] Updates synced when connectivity restored
- [ ] Stale data clearly indicated

### AC5: Multi-National Reporting
- [ ] 15+ nations can report logistics status in common format
- [ ] National classifications respected alongside NATO classification
- [ ] National caveats enforced on logistics data
- [ ] Federated KAS per nation for logistics data

### AC6: Comprehensive Audit Trail
- [ ] All logistics data contributions logged
- [ ] Aggregation operations logged
- [ ] Commercial and host nation access logged
- [ ] Logistics data lifecycle tracked (creation to consumption)

## Success Metrics

- **Data Availability**: Logistics planners have timely, complete readiness picture
- **Aggregation Security**: Combined readiness data protected at appropriate level
- **Partner Access**: Commercial and host nation partners receive needed data
- **DDIL Reach**: Deployed units access logistics status in degraded connectivity
- **Audit Completeness**: Full logistics data lifecycle tracked

## Out of Scope

- Procurement and contracting processes
- Financial/budget data for logistics
- Warehouse management systems
- Vehicle fleet management systems

## Related Scenarios

- **Scenario 02**: Tactical DDIL -- logistics data in degraded connectivity
- **Scenario 05**: Mission-based sharing -- logistics data scoped to specific operations
- **Scenario 16**: Defence industrial base -- supply chain data protection

---
