# Step 1: Create the S3 Data Bucket

We need an S3 bucket to store our labeled data objects. We'll enable versioning so we can track changes to labels over time, and add encryption at rest as baseline protection.

## Create the bucket

1. Open the **S3 Console**: [https://console.aws.amazon.com/s3](https://console.aws.amazon.com/s3)
2. Click **Create bucket**
3. Set the following:
    - **Bucket name**: `dcs-level1-data-{your-account-id}` (bucket names must be globally unique, so append your account ID)
    - **Region**: eu-west-2 (or your preferred region)
    - **Object Ownership**: ACLs disabled
    - **Block all public access**: Checked (leave all four boxes ticked)
    - **Bucket Versioning**: Enable
    - **Default encryption**: Server-side encryption with AWS managed keys (SSE-S3)
4. Click **Create bucket**

## Create the audit bucket

We also need a separate bucket for CloudTrail logs:

1. Click **Create bucket** again
2. Set:
    - **Bucket name**: `dcs-level1-audit-{your-account-id}`
    - **Region**: Same as above
    - **Block all public access**: Checked
    - **Bucket Versioning**: Enable
3. Click **Create bucket**

## Upload test data

Now let's upload three files with different security levels. Create these files on your local machine:

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

1. Open your `dcs-level1-data-...` bucket
2. Click **Upload**
3. Add all three files
4. Click **Upload**

!!! info "No labels yet"
    Right now these files have no security labels. In the next step, we'll add labels as S3 tags. This is the "before" state - data without DCS.
