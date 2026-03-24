# Step 2: Set Up Security Labels

Now we'll add DCS labels to our data objects. In a real STANAG-compliant system, these would be STANAG 4774 XML labels cryptographically bound to the data (STANAG 4778). Here, we're using S3 object tags as a simplified equivalent to focus on the concepts: what labels contain and how they travel with data.

## Add labels to each file

### logistics-report.txt — UNCLASSIFIED

1. In your S3 bucket, click on **logistics-report.txt**
2. Go to the **Properties** tab
3. Scroll to **Tags** and click **Edit**
4. Add these tags:

| Key | Value |
|-----|-------|
| `dcs:classification` | `UNCLASSIFIED` |
| `dcs:releasable-to` | `ALL` |
| `dcs:sap` | `NONE` |
| `dcs:originator` | `USA` |

5. Click **Save changes**

### intel-report.txt — SECRET, coalition-releasable

1. Click on **intel-report.txt**
2. Go to **Properties** > **Tags** > **Edit**
3. Add:

| Key | Value |
|-----|-------|
| `dcs:classification` | `SECRET` |
| `dcs:releasable-to` | `GBR,USA,POL` |
| `dcs:sap` | `NONE` |
| `dcs:originator` | `POL` |

4. Click **Save changes**

### operation-wall.txt — SECRET + WALL SAP, UK-originated

1. Click on **operation-wall.txt**
2. Go to **Properties** > **Tags** > **Edit**
3. Add:

| Key | Value |
|-----|-------|
| `dcs:classification` | `SECRET` |
| `dcs:releasable-to` | `GBR,USA,POL` |
| `dcs:sap` | `WALL` |
| `dcs:originator` | `GBR` |

4. Click **Save changes**

## What you just did

You've attached security metadata to three data objects:

- **logistics-report.txt**: UNCLASSIFIED, released to ALL, no SAP
- **intel-report.txt**: SECRET, releasable to GBR/USA/POL, no SAP
- **operation-wall.txt**: SECRET, releasable to GBR/USA/POL, requires WALL SAP

These labels are now part of each object's metadata. If you copy these objects to another S3 bucket, the tags go with them. This is the DCS principle: security metadata travels with the data.

## Try it: View labels programmatically

If you have the AWS CLI installed, you can read labels with:

```bash
aws s3api get-object-tagging \
  --bucket dcs-lab-data-YOUR-ACCOUNT-ID \
  --key intel-report.txt
```

You'll see output like:
```json
{
  "TagSet": [
    { "Key": "dcs:classification", "Value": "SECRET" },
    { "Key": "dcs:releasable-to", "Value": "GBR,USA,POL" },
    { "Key": "dcs:sap", "Value": "NONE" },
    { "Key": "dcs:originator", "Value": "POL" }
  ]
}
```

## Try it: Copy an object and check labels follow

```bash
aws s3 cp \
  s3://dcs-lab-data-YOUR-ACCOUNT-ID/intel-report.txt \
  s3://dcs-lab-data-YOUR-ACCOUNT-ID/intel-report-copy.txt

aws s3api get-object-tagging \
  --bucket dcs-lab-data-YOUR-ACCOUNT-ID \
  --key intel-report-copy.txt
```

The copy has the same tags. Labels travel with the data. This is a key property of DCS Level 1 — the security metadata isn't stored in a separate system that might get out of sync. It's attached to the data itself.

!!! warning "Labels are advisory at this point"
    Anyone with S3 access can download and read all three files regardless of labels. The labels are just metadata — they describe how the data should be handled, but nothing enforces that yet. Anyone with S3 tagging permissions can also silently change the labels. In the Assured DCS Level 1 architecture, labels are cryptographically signed (STANAG 4778), so tampering is detectable.

Next: **[Step 3: Build the Data Service](step3-service.md)**
