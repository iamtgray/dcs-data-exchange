# Step 3: Confirm Your Labeled Data

We're reusing the S3 bucket and labeled objects from Lab 1. No new data to create, just confirm everything is in place and understand the expected access matrix.

## Check your S3 objects

Open your `dcs-lab-data-...` bucket and verify you have these three objects with their labels:

| Object | Classification | Releasable To | SAP | Originator |
|--------|---------------|---------------|-----|------------|
| logistics-report.txt | UNCLASSIFIED | ALL | NONE | USA |
| intel-report.txt | SECRET | GBR,USA,POL | NONE | POL |
| operation-wall.txt | SECRET | GBR,USA,POL | WALL | GBR |

If you tampered with the intel-report.txt labels in Lab 1 Step 4, make sure you restored them.

## Expected access matrix

Based on our Cedar policies from Step 2 and these labels, here's what should happen:

| Object | UK (SECRET, GBR, WALL) | Poland (NATO-SECRET, POL, no SAPs) | US (IL-6, USA, WALL) |
|--------|:---:|:---:|:---:|
| logistics-report.txt | ALLOW | ALLOW | ALLOW |
| intel-report.txt | ALLOW | ALLOW | ALLOW |
| operation-wall.txt | ALLOW | **DENY** (no WALL SAP) | ALLOW |

The UK analyst can see everything. The Polish analyst can see everything except the WALL report (missing SAP). The US analyst can see everything.

!!! note "What about uk-eyes-only data?"
    In Lab 1 we only created three objects. If you want to test nationality-based denial, you can add a fourth object with `dcs:releasable-to = GBR` only. The Cedar policies will deny access to Polish and US users automatically.

## How labels feed into Cedar policies

The Lambda will read S3 tags and pass them to Verified Permissions as entity attributes. Here's the mapping:

| S3 Tag | Cedar Entity Attribute | Type |
|--------|----------------------|------|
| `dcs:classification` | Mapped to `classificationLevel` (numeric) | Long |
| `dcs:releasable-to` | Split into `releasableTo` set | Set of Strings |
| `dcs:sap` | `requiredSap` | String |
| `dcs:originator` | `originator` | String |

The Lambda handles the conversion, turning "SECRET" into `2`, splitting "GBR,USA,POL" into a set, etc. The Cedar policies work with the structured attributes.

Next: **[Step 4: Add Access Control to the Data Service](step4-service.md)**
