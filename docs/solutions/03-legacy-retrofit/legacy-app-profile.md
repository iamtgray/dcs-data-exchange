# Legacy application profile: NATO Joint Logistics Tracking System (JLTS)


*This is a fictional but representative legacy application profile, based on common characteristics of NATO-era logistics systems. It is used as a concrete example for exploring DCS retrofit approaches.*


## Background

The Joint Logistics Tracking System (JLTS) was commissioned in 2004 by NATO's Support and Procurement Agency (NSPA) to consolidate logistics tracking across allied nations participating in ISAF operations. It replaced a patchwork of national spreadsheets and fax-based reporting with a centralised system for tracking materiel movements, supply requests, and maintenance schedules across theatre.

JLTS was built by a defence contractor using IBM mainframe technology that was already mature at the time. The system was designed for a single security domain (NATO SECRET) and assumed that anyone with network access and a valid login was cleared to see everything in the system. It was never designed for multi-level security or granular access control.

Twenty years later, JLTS is still running. It has survived multiple attempts at replacement, each cancelled due to cost overruns or shifting priorities. The system now supports logistics coordination across several NATO operations and exercises, and has accumulated two decades of operational data that nobody wants to migrate.

## System architecture

### Application layer

JLTS is a batch-and-terminal application written in approximately 340,000 lines of COBOL-85, running on an IBM z/OS mainframe. The application consists of:

- **CICS Transaction Server**: Handles all interactive user sessions via 3270 terminal emulation. Users connect through TN3270 terminal emulators running on their workstations, or increasingly through a web-based 3270 emulator (a thin Java applet added in 2012 that simply renders the green-screen interface in a browser).
- **Batch Processing**: Approximately 180 batch COBOL programs run on nightly and weekly schedules via JCL (Job Control Language). These handle report generation, data reconciliation between national feeds, supply forecasting, and archive operations.
- **CICS Programs**: Around 90 online CICS transaction programs handle interactive queries, data entry, and real-time status updates.

The COBOL code is maintained by a small team (three developers, two of whom are approaching retirement) at a contractor facility. Changes are infrequent and conservative -- typically fewer than 10 change requests per year, mostly regulatory or format changes to national reporting feeds.

### Database layer

JLTS uses IBM DB2 for z/OS (version 12) as its sole data store. The database contains:

- **Core Tables**: 147 tables across 12 tablespaces
- **Data Volume**: Approximately 380 GB of active data, plus 2.1 TB in archive partitions
- **Key Entities**: Supply requests, materiel movements, unit locations, maintenance records, personnel assignments (logistics roles only), vendor contracts, and national contribution tracking

The DB2 schema was designed in 2003 and has been extended incrementally over the years. It reflects the conventions of its era:

- Column names are abbreviated to 8 characters (e.g., `MVMT_TYP` for movement type, `CLF_LVL` for classification level, `UNIT_LOC` for unit location)
- Heavy use of packed decimal fields for quantities and costs
- Composite primary keys rather than surrogate keys
- No foreign key constraints enforced at the database level (referential integrity managed in COBOL application logic)
- Several "catch-all" VARCHAR columns repurposed over the years for data they were never designed to hold

### Data classification reality

The database was designed for a single classification level (NATO SECRET), but operational reality has diverged significantly:

| Data Category | Actual Sensitivity | Current Labeling | Volume |
|---|---|---|---|
| Unit locations and movements | NATO SECRET | None (assumed NS) | ~45,000 active records |
| Supply request details | NATO CONFIDENTIAL to SECRET | None | ~120,000 active records |
| Vendor contract terms | NATO RESTRICTED | None | ~8,000 records |
| Maintenance schedules | NATO RESTRICTED to CONFIDENTIAL | None | ~65,000 records |
| Personnel assignments | NATO SECRET + national caveats | None | ~12,000 records |
| National contribution data | NATO CONFIDENTIAL + REL TO [nation] | None | ~30,000 records |
| Administrative/reference data | NATO UNCLASSIFIED | None | ~200,000 records |
| Archived operational data | Mixed (NS/NC/NR) | None | ~15 million records |

The `CLF_LVL` column exists in several tables but was populated inconsistently during the first two years of operation and then largely abandoned. Approximately 30% of records have a value in this field; of those, an estimated 40% are inaccurate based on a 2019 audit sample.

### Authentication and access control

User authentication is handled by RACF (Resource Access Control Facility) on the z/OS mainframe:

- **User Accounts**: Approximately 850 active user accounts across 14 NATO nations
- **Authentication**: RACF user ID and password, with some nations using PKI certificates mapped to RACF IDs
- **Authorisation**: Binary -- users either have access to JLTS or they don't. There are three RACF groups:
    - `JLTS-USER`: Read access to all data, create/update supply requests
    - `JLTS-ADMIN`: Full read/write access to all data
    - `JLTS-BATCH`: Service account for batch processing
- **No Attribute-Based Controls**: No concept of filtering data based on user clearance level, nationality, or need-to-know
- **No Row-Level Security**: DB2 views are used for some reporting purposes but not for access control

### Network and infrastructure

- **Hosting**: IBM z15 mainframe at a NATO facility, connected to the NATO Secret WAN (NSWN)
- **Connectivity**: Users access JLTS over NSWN from national terminals at NATO HQs and national liaison offices
- **Interfaces**: 
    - Inbound: Nightly batch feeds from 8 national logistics systems (flat file format, FTP)
    - Outbound: Weekly summary reports distributed via secure email
    - No APIs, no web services, no REST endpoints

### Known technical debt

- **No Source Control**: COBOL source is managed in PDS (Partitioned Data Set) libraries on the mainframe. A copy is periodically exported to a shared drive, but there is no formal version control.
- **Limited Documentation**: Original design documents exist but are significantly out of date. Most system knowledge is held by the two senior developers.
- **No Test Environment**: Changes are tested in a "development CICS region" that shares the production DB2 instance (using a separate schema). There is no isolated test database with representative data.
- **Hardcoded Values**: Business rules, classification assumptions, and national-specific logic are embedded throughout the COBOL code rather than externalised in configuration.
- **Character Encoding**: All data is stored in EBCDIC. Interfaces with modern systems require character set conversion.

## Operational context

### Who uses JLTS

| User Group | Count | Typical Use | Access Pattern |
|---|---|---|---|
| NATO HQ logistics staff | ~120 | Daily supply tracking, reporting | Interactive, 8-hour shifts |
| National liaison officers | ~280 | National contribution queries, supply requests | Interactive, business hours |
| National logistics systems | 8 | Automated data feeds | Batch, nightly |
| NSPA procurement staff | ~45 | Vendor management, contract tracking | Interactive, business hours |
| Exercise planners | ~60 | Exercise logistics planning (periodic) | Interactive, surge during exercises |
| Auditors | ~15 | Compliance reviews, data quality checks | Interactive, quarterly |
| System administrators | 5 | System maintenance, user management | Interactive + batch |
| Batch service accounts | 3 | Automated processing | Batch, scheduled |

### Why it can't be replaced (yet)

1. **Data Migration Risk**: 2.5 TB of operational and archived data with inconsistent formats, undocumented business rules embedded in COBOL, and no comprehensive data dictionary
2. **Integration Dependencies**: 8 national systems feed data to JLTS in bespoke flat-file formats negotiated bilaterally over 20 years
3. **Institutional Knowledge**: The system encodes logistics business rules that exist nowhere else in written form
4. **Budget Constraints**: Two previous replacement programmes were cancelled after spending significant budgets
5. **Operational Continuity**: JLTS supports active operations and cannot have extended downtime for migration

### The DCS problem

JLTS violates data-centric security principles in several fundamental ways:

1. **No Data Labeling**: Data sensitivity is not systematically recorded. The `CLF_LVL` field is unreliable.
2. **No Granular Access Control**: A French liaison officer with NATO CONFIDENTIAL clearance sees the same data as a US logistics commander with NATO SECRET + COSMIC clearance.
3. **No Content Filtering**: National contribution data marked "REL TO [nation]" is visible to all users regardless of nationality.
4. **No Audit of Data Access by Sensitivity**: RACF logs show who logged in, but not what classification of data they accessed.
5. **Mixed Sensitivity in Single Records**: A supply request record might contain unclassified item descriptions alongside SECRET unit location data in the same row.

### What makes this hard

- The COBOL application has no concept of "the current user's clearance" -- it doesn't pass user attributes to DB2 queries
- DB2 queries are embedded in COBOL as static SQL, compiled into load modules -- they can't be dynamically modified at runtime
- The 3270 terminal interface renders fixed-format screens defined in BMS (Basic Mapping Support) maps -- there's no easy way to conditionally hide fields
- Batch processing runs under service accounts with no concept of "on behalf of" a specific user
- The data model mixes sensitivity levels within single rows (e.g., unclassified item description + SECRET destination unit in the same supply request record)

## Summary

JLTS is a textbook example of the legacy DCS retrofit challenge: a system that works, that people depend on, that contains sensitive data of varying classifications, and that was built in an era when "if you're on the network, you're cleared to see everything" was an acceptable security model. The question is how to apply DCS Levels 1, 2, and 3 to this system without rewriting it, without breaking it, and without the three remaining developers who understand it retiring before the work is done.

---
