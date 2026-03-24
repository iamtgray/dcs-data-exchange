# Step 4: Test the Data Service

Let's call our data service and see what comes back. The key thing to notice: every response includes the data's labels. The service doesn't care who you are -- it returns everything.

## Test using curl

Replace `YOUR_FUNCTION_URL` with the Lambda Function URL you copied in Step 3.

### Request the logistics report

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"objectKey": "logistics-report.txt"}' | python3 -m json.tool
```

```json
{
  "object": "logistics-report.txt",
  "labels": {
    "dcs:classification": "UNCLASSIFIED",
    "dcs:releasable-to": "ALL",
    "dcs:sap": "NONE",
    "dcs:originator": "USA"
  },
  "content": "LOGISTICS SUMMARY - Q1 2025\nSupply levels normal across all forward operating bases.\nNo classified information in this report.\n"
}
```

### Request the intelligence report

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"objectKey": "intel-report.txt"}' | python3 -m json.tool
```

```json
{
  "object": "intel-report.txt",
  "labels": {
    "dcs:classification": "SECRET",
    "dcs:releasable-to": "GBR,USA,POL",
    "dcs:sap": "NONE",
    "dcs:originator": "POL"
  },
  "content": "INTELLIGENCE ASSESSMENT - NORTHERN SECTOR\nEnemy forces observed moving through GRID 12345678..."
}
```

### Request the WALL report

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"objectKey": "operation-wall.txt"}' | python3 -m json.tool
```

```json
{
  "object": "operation-wall.txt",
  "labels": {
    "dcs:classification": "SECRET",
    "dcs:releasable-to": "GBR,USA,POL",
    "dcs:sap": "WALL",
    "dcs:originator": "GBR"
  },
  "content": "OPERATION WALL - PHASE 2 UPDATE\nUK HUMINT sources report enemy command structure reorganisation..."
}
```

## Notice what happened

All three requests succeeded. The service returned the SECRET intelligence report and the WALL-compartmented operation report just as happily as the UNCLASSIFIED logistics report. There's no access control. No one checked clearance, nationality, or SAP access.

But look at the responses: every one includes the `labels` field. A downstream system receiving this data knows:

- **logistics-report.txt** is UNCLASSIFIED, releasable to everyone
- **intel-report.txt** is SECRET, releasable to GBR/USA/POL only
- **operation-wall.txt** is SECRET, requires WALL SAP, originated from GBR

The labels are there. They describe how the data should be handled. They just aren't being enforced.

## Try it: Tamper with a label

Let's see what happens when someone changes a label:

```bash
aws s3api put-object-tagging \
  --bucket dcs-lab-data-YOUR-ACCOUNT-ID \
  --key intel-report.txt \
  --tagging 'TagSet=[{Key=dcs:classification,Value=UNCLASSIFIED},{Key=dcs:releasable-to,Value=ALL},{Key=dcs:sap,Value=NONE},{Key=dcs:originator,Value=POL}]'
```

Now request it again:

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"objectKey": "intel-report.txt"}' | python3 -m json.tool
```

The intelligence report now comes back labeled UNCLASSIFIED. The data hasn't changed -- it's still a SECRET intelligence assessment -- but the label says otherwise. Nobody was alerted. Nothing stopped it.

!!! danger "Fix the label before continuing"
    Put the correct label back:

    ```bash
    aws s3api put-object-tagging \
      --bucket dcs-lab-data-YOUR-ACCOUNT-ID \
      --key intel-report.txt \
      --tagging 'TagSet=[{Key=dcs:classification,Value=SECRET},{Key=dcs:releasable-to,Value="GBR,USA,POL"},{Key=dcs:sap,Value=NONE},{Key=dcs:originator,Value=POL}]'
    ```

This is why basic Level 1 is just the starting point. Labels without enforcement are suggestions. Labels without cryptographic binding can be silently changed. You need Level 2 (access control) and assured labeling (STANAG 4778 signatures) to make labels meaningful.

Next: **[Step 5: Review the Audit Trail](step5-audit.md)**
