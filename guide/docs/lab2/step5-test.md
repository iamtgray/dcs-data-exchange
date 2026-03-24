# Step 5: Test ABAC Scenarios

Let's test the updated data service. The requests now include user attributes alongside the object key. Compare the responses to Lab 1 — when access is allowed, you get the same data and labels. When it's denied, you get the labels but not the content.

## Test using curl

Use the same Function URL from Lab 1.

### Test 1: UK analyst reads coalition intelligence

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "intel-report.txt",
    "username": "uk-analyst-01",
    "clearanceLevel": 2,
    "nationality": "GBR",
    "saps": ["WALL"]
  }' | python3 -m json.tool
```

**Expected: ALLOWED** — clearance 2 >= classification SECRET (2), GBR in releasable-to, no SAP required.

The response includes the data content and labels, just like Lab 1, plus `determiningPolicies` showing which Cedar policy allowed it.

### Test 2: Polish analyst reads WALL report

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "operation-wall.txt",
    "username": "pol-analyst-01",
    "clearanceLevel": 2,
    "nationality": "POL",
    "saps": []
  }' | python3 -m json.tool
```

**Expected: DENIED** — Polish analyst doesn't have the WALL SAP.

```json
{
  "object": "operation-wall.txt",
  "labels": {
    "dcs:classification": "SECRET",
    "dcs:releasable-to": "GBR,USA,POL",
    "dcs:sap": "WALL",
    "dcs:originator": "GBR"
  },
  "allowed": false,
  "user": "pol-analyst-01",
  "determiningPolicies": []
}
```

Notice: the labels are returned (the caller can see what the data requires) but the content is not. This is the difference from Lab 1 — the same request in Lab 1 would have returned the full content.

### Test 3: UK analyst reads WALL report

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "operation-wall.txt",
    "username": "uk-analyst-01",
    "clearanceLevel": 2,
    "nationality": "GBR",
    "saps": ["WALL"]
  }' | python3 -m json.tool
```

**Expected: ALLOWED** — UK analyst has SECRET clearance, GBR nationality, and the WALL SAP.

### Test 4: Contractor with no clearance

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "intel-report.txt",
    "username": "contractor-01",
    "clearanceLevel": 0,
    "nationality": "GBR",
    "saps": []
  }' | python3 -m json.tool
```

**Expected: DENIED** — clearance level 0 is blocked by the `forbid` policy, even though GBR is in the releasable-to list.

### Test 5: Everyone can read unclassified data

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "logistics-report.txt",
    "username": "pol-analyst-01",
    "clearanceLevel": 2,
    "nationality": "POL",
    "saps": []
  }' | python3 -m json.tool
```

**Expected: ALLOWED** — UNCLASSIFIED, releasable to ALL.

## Full results matrix

| Object | UK (SECRET, GBR, WALL) | Poland (NS, POL, none) | US (IL-6, USA, WALL) |
|--------|:---:|:---:|:---:|
| logistics-report.txt (UNCLASS, ALL) | ALLOW | ALLOW | ALLOW |
| intel-report.txt (SECRET, GBR/USA/POL) | ALLOW | ALLOW | ALLOW |
| operation-wall.txt (SECRET, GBR/USA/POL, SAP:WALL) | ALLOW | **DENY** | ALLOW |

## What's different from Lab 1

In Lab 1, every request returned the data. Now:

- The Lambda checks Verified Permissions before returning content
- Denied requests get a 403 with labels but no content
- Allowed requests include `determiningPolicies` showing which Cedar policy permitted access
- The Lambda has no access logic of its own — it just relays the policy engine's decision

The data hasn't changed. The labels haven't changed. The only new thing is the policy check.

Next: **[Step 6: Change Policies Dynamically](step6-dynamic.md)**
