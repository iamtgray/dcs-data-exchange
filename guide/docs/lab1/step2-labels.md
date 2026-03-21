# Step 2: Set Up Security Labels

Now we'll add DCS labels to our data objects. In a real STANAG-compliant system, these would be STANAG 4774 XML labels cryptographically bound to the data (STANAG 4778). Here, we're using S3 object tags as a simplified equivalent to focus on the concepts: what labels contain and how they drive access decisions.

## Add labels to each file

### logistics-report.txt - UNCLASSIFIED

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

### intel-report.txt - SECRET, coalition-releasable

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

### operation-wall.txt - SECRET + WALL SAP, UK-originated

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

- logistics-report.txt: Anyone can read it (UNCLASSIFIED, released to ALL)
- intel-report.txt: Requires SECRET clearance and GBR/USA/POL nationality
- operation-wall.txt: Requires SECRET clearance, GBR/USA/POL nationality, AND the WALL special access program

These labels are now part of each object's metadata. If you copy these objects to another S3 bucket, the tags go with them. This is the DCS principle: security metadata travels with the data.

!!! abstract "How this compares to STANAG 4774"
    In a STANAG-compliant system, these labels would be XML documents stored separately from the data (e.g., in a DynamoDB label store), with a `PolicyIdentifier` specifying the classification scheme and typed `Category` elements distinguishing PERMISSIVE (releasability) from RESTRICTIVE (SAP) requirements. The S3 tags we're using here carry the same information in a simpler format, good enough to learn the concepts but not interoperable with other NATO systems.

## Try it: View labels programmatically

If you have the AWS CLI installed, you can read labels with:

```bash
aws s3api get-object-tagging \
  --bucket dcs-level1-data-YOUR-ACCOUNT-ID \
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

!!! warning "Labels are advisory at this point"
    Anyone with S3 access can still download and read all three files regardless of labels. The labels are just metadata; they don't enforce anything yet. That's why we need the authorizer in Step 4. And even with the authorizer, anyone with S3 tagging permissions can silently change the labels. In the Assured DCS Level 1 architecture, labels are cryptographically signed (STANAG 4778), so tampering is detectable.

Next: **[Step 3: Create Simulated Users](step3-users.md)** to represent people with different clearance levels.
