# Step 5: Test Access Decisions

Now let's test our DCS Level 1 system. We'll make requests as each of our three users against each of the three files and see whether access is granted or denied.

## Test using curl

Replace `YOUR_FUNCTION_URL` with the Lambda Function URL you copied in Step 4.

### Test 1: UK SECRET analyst accessing the intelligence report

```bash
curl -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dcs-user-gbr-secret",
    "objectKey": "intel-report.txt"
  }'
```

**Expected result: ALLOWED**

The UK analyst has SECRET clearance (level 2), the report requires SECRET (level 2). UK (GBR) is in the releasable-to list. No SAP required.

```json
{
  "allowed": true,
  "user": "dcs-user-gbr-secret",
  "object": "intel-report.txt",
  "userAttributes": {
    "dcs:clearance": "SECRET",
    "dcs:nationality": "GBR",
    "dcs:saps": "WALL"
  },
  "objectLabels": {
    "dcs:classification": "SECRET",
    "dcs:releasable-to": "GBR,USA,POL",
    "dcs:sap": "NONE",
    "dcs:originator": "POL"
  }
}
```

### Test 2: UK SECRET analyst accessing WALL report

```bash
curl -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dcs-user-gbr-secret",
    "objectKey": "operation-wall.txt"
  }'
```

**Expected result: ALLOWED**

UK analyst has SECRET clearance, GBR nationality, AND the WALL SAP. All three checks pass.

### Test 3: Polish analyst accessing the intelligence report

```bash
curl -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dcs-user-pol-ns",
    "objectKey": "intel-report.txt"
  }'
```

**Expected result: ALLOWED**

Polish analyst has NATO-SECRET (maps to level 2 = SECRET). POL is in releasable-to. No SAP required.

### Test 4: Polish analyst accessing WALL report

```bash
curl -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dcs-user-pol-ns",
    "objectKey": "operation-wall.txt"
  }'
```

**Expected result: DENIED**

Polish analyst meets the clearance and nationality requirements, but does NOT have the WALL SAP.

```json
{
  "allowed": false,
  "user": "dcs-user-pol-ns",
  "object": "operation-wall.txt",
  "denialReasons": [
    "Missing SAP: data requires WALL, user has none"
  ]
}
```

### Test 5: Contractor accessing the intelligence report

```bash
curl -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dcs-user-contractor",
    "objectKey": "intel-report.txt"
  }'
```

**Expected result: DENIED**

Contractor has UNCLASSIFIED clearance (level 0), report requires SECRET (level 2).

```json
{
  "allowed": false,
  "user": "dcs-user-contractor",
  "object": "intel-report.txt",
  "denialReasons": [
    "Clearance too low: user has UNCLASSIFIED (level 0), data requires SECRET (level 2)"
  ]
}
```

### Test 6: Contractor accessing the logistics report

```bash
curl -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dcs-user-contractor",
    "objectKey": "logistics-report.txt"
  }'
```

**Expected result: ALLOWED**

Logistics report is UNCLASSIFIED, releasable to ALL. Even the contractor can read it.

## Results summary

| User | logistics-report | intel-report | operation-wall |
|------|:---:|:---:|:---:|
| UK SECRET + WALL | ALLOWED | ALLOWED | ALLOWED |
| Polish NATO-SECRET | ALLOWED | ALLOWED | **DENIED** (no WALL SAP) |
| Contractor UNCLASSIFIED | ALLOWED | **DENIED** (clearance) | **DENIED** (clearance + SAP) |

## What just happened

The Lambda function made access decisions by comparing user attributes against data labels:

- Classification check: Is the user's clearance level >= the data's classification?
- Nationality check: Is the user's country in the data's releasable-to list?
- SAP check: Does the user have any required special access programs?

All three checks must pass for access to be granted. The decision and all context are logged, creating an audit trail.

!!! tip "Think about what we didn't do"
    We never created complex IAM policies for each user-object combination. We didn't create roles like "people who can read intel-report but not operation-wall." The access decisions come from comparing attributes against labels. That's the power of data-centric security: it scales without an explosion of permissions.

Next: **[Step 6: Review the Audit Trail](step6-audit.md)**.
