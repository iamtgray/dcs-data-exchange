# Step 5: Test ABAC Scenarios

Let's test our DCS Level 2 system by making requests as different users against different data items.

## Test using curl

Replace `YOUR_FUNCTION_URL` with your Lambda Function URL.

### Test 1: UK analyst reads coalition intelligence

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "uk-analyst-01",
    "clearanceLevel": 2,
    "nationality": "GBR",
    "saps": ["WALL"],
    "dataId": "intel-report-001"
  }' | python3 -m json.tool
```

**Expected: ALLOW** - UK analyst has SECRET (level 2), GBR is in releasable-to, no SAP required.

### Test 2: Polish analyst reads WALL report

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "pol-analyst-01",
    "clearanceLevel": 2,
    "nationality": "POL",
    "saps": [],
    "dataId": "wall-report-003"
  }' | python3 -m json.tool
```

**Expected: DENY** - Polish analyst doesn't have the WALL SAP.

### Test 3: US analyst reads UK-eyes-only

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "us-analyst-01",
    "clearanceLevel": 2,
    "nationality": "USA",
    "saps": ["WALL"],
    "dataId": "uk-eyes-only-002"
  }' | python3 -m json.tool
```

**Expected: DENY** - USA is not in the releasable-to list (GBR only), and USA is not the originator (GBR is).

### Test 4: UK analyst reads UK-eyes-only

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "uk-analyst-01",
    "clearanceLevel": 2,
    "nationality": "GBR",
    "saps": ["WALL"],
    "dataId": "uk-eyes-only-002"
  }' | python3 -m json.tool
```

**Expected: ALLOW** - GBR is in releasable-to, AND GBR is the originator (both policies match).

### Test 5: Revoked clearance

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "revoked-user",
    "clearanceLevel": 0,
    "nationality": "GBR",
    "saps": ["WALL"],
    "dataId": "logistics-004"
  }' | python3 -m json.tool
```

**Expected: DENY** - Even though the logistics report is UNCLASSIFIED and released to ALL, the forbid policy blocks users with clearance level 0.

## Full results matrix

| Data Item | UK (SECRET, GBR, WALL) | Poland (NS, POL, none) | US (IL-6, USA, WALL) |
|-----------|:---:|:---:|:---:|
| intel-report-001 (SECRET, GBR/USA/POL) | ALLOW | ALLOW | ALLOW |
| wall-report-003 (SECRET, GBR/USA/POL, SAP:WALL) | ALLOW | **DENY** | ALLOW |
| uk-eyes-only-002 (SECRET, GBR only) | ALLOW | **DENY** | **DENY** |
| logistics-004 (UNCLASS, ALL) | ALLOW | ALLOW | ALLOW |

## What's different from Lab 1

The results are the same, but the mechanism is fundamentally different:

1. **The Lambda has no access logic.** It doesn't know what SECRET means or how to compare clearances. It just passes attributes to Verified Permissions and acts on the response.

2. **The policies are separate from the code.** You can see them in the Verified Permissions console, test them in the test bench, and change them without touching the Lambda.

3. **The response tells you which policy decided.** The `authorizedBy` field in the ALLOW response shows which Cedar policy(ies) permitted the access. This is much better for auditing.

Next: **[Step 6: Change Policies Dynamically](step6-dynamic.md)**
