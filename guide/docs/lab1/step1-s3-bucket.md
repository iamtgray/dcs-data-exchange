# Step 1: Create the S3 Data Bucket

We need an S3 bucket to store our data objects. We'll enable versioning so we can track changes to labels over time, and add encryption at rest as baseline protection.

## Create the bucket

1. Open the **S3 Console**: [https://console.aws.amazon.com/s3](https://console.aws.amazon.com/s3)
2. Click **Create bucket**
3. Set the following:
    - **Bucket name**: `dcs-lab-data-{your-account-id}` (bucket names must be globally unique, so append your account ID)
    - **Region**: eu-west-2 (or your preferred region)
    - **Object Ownership**: ACLs disabled
    - **Block all public access**: Checked (leave all four boxes ticked)
    - **Bucket Versioning**: Enable
    - **Default encryption**: Server-side encryption with AWS managed keys (SSE-S3)
4. Click **Create bucket**

## Upload test data

Now let's upload three files that represent data with different sensitivity levels. Create these files on your local machine:

**File 1: `logistics-report.txt`**
```
LOGISTICS SUMMARY - Q1 2025
Supply levels normal across all forward operating bases.
No classified information in this report.
```

**File 2: `intel-report.txt`**
```
INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
Enemy forces observed moving through GRID 12345678.
Estimated 200 personnel with armoured vehicles.
Movement pattern suggests preparation for offensive operations.
Recommend increased surveillance.
```

**File 3: `operation-wall.txt`**
```
OPERATION WALL - PHASE 2 UPDATE
UK HUMINT sources report enemy command structure reorganisation.
Source reliability: A2. Information confirmed by SIGINT.
Coalition response options being developed.
```

Upload all three to your data bucket:

1. Open your `dcs-lab-data-...` bucket
2. Click **Upload**
3. Add all three files
4. Click **Upload**

!!! info "No labels yet"
    Right now these files have no security labels. They're just files in a bucket. In the next step, we'll add labels as S3 tags. This is the "before" state — data without DCS.

Next: **[Step 2: Set Up Security Labels](step2-labels.md)**
