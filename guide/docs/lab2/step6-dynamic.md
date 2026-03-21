# Step 6: Change Policies Dynamically

This step shows the real power of DCS Level 2: you can change access rules without touching the data or the code. Policies are separate from both, and changes take effect immediately.

## Scenario: Exercise IRON SHIELD

Imagine NATO is running a joint exercise. Sweden (SWE) needs temporary access to coalition intelligence. Instead of re-labeling every data item, we just add a policy.

### Add a temporary access policy

1. Go to your **Verified Permissions policy store**
2. Go to **Policies** > **Create static policy**
3. **Description**: `Temporary exercise access - IRON SHIELD - Sweden`
4. **Policy body**:

```cedar
permit(
  principal is DCS::User,
  action == DCS::Action::"read",
  resource is DCS::DataObject
) when {
  principal.nationality == "SWE" &&
  principal.clearanceLevel >= resource.classificationLevel &&
  resource.requiredSap == ""
};
```

5. Click **Create policy**

### Test it

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "swe-observer-01",
    "clearanceLevel": 2,
    "nationality": "SWE",
    "saps": [],
    "dataId": "intel-report-001"
  }' | python3 -m json.tool
```

**Result: ALLOW** - The new policy grants Sweden access to non-SAP data that matches their clearance level. Notice:

- We didn't change any data labels
- We didn't change the Lambda code
- We didn't add Sweden to any releasable-to lists
- We just added a policy, and it took effect immediately

### Test SAP data is still protected

```bash
curl -s -X POST YOUR_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "swe-observer-01",
    "clearanceLevel": 2,
    "nationality": "SWE",
    "saps": [],
    "dataId": "wall-report-003"
  }' | python3 -m json.tool
```

**Result: DENY** - The temporary policy explicitly requires `requiredSap == ""`, so SAP-protected data remains off-limits for Sweden.

## Scenario: Revoke the temporary access

Exercise is over. Remove Sweden's access:

1. Go to **Policies** in your policy store
2. Find the "Temporary exercise access - IRON SHIELD - Sweden" policy
3. Click **Delete** > confirm

Now rerun the Sweden test - it will return DENY. Access is revoked instantly, across all data, without touching anything else.

## Scenario: Add an exception

The UK commander decides that Polish analysts should temporarily get WALL SAP access for a specific operation:

1. Create a new static policy:

```cedar
permit(
  principal is DCS::User,
  action == DCS::Action::"read",
  resource is DCS::DataObject
) when {
  principal.nationality == "POL" &&
  principal.clearanceLevel >= 2 &&
  resource.requiredSap == "WALL"
};
```

2. Test:

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

**Result: ALLOW** - The exception policy grants access even though the Polish analyst doesn't have the WALL SAP in their attributes.

!!! tip "This is the point"
    In Lab 1, changing access rules meant editing Python code and redeploying a Lambda. In Lab 2, it means adding or removing a Cedar policy in a console. That's the difference between hard-coded logic and a proper policy engine. In real operations, policy changes need to be fast and auditable, and they shouldn't require a software deployment.

## Review the audit trail

Check CloudWatch Logs for your Lambda. Every request now includes:

- Which policies were evaluated
- Which specific policy allowed or denied access
- The full attribute context

This means auditors can trace not just "was access granted" but "which policy granted it and why."

Next: **[What You Learned](summary.md)**
