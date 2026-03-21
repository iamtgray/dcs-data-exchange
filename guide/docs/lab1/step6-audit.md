# Step 6: Review the Audit Trail

Every DCS system needs a complete audit trail. In our Level 1 architecture, audit happens in two places: Lambda logs (our access decisions) and CloudTrail (S3 operations).

## View access decision logs

1. Go to **CloudWatch Console**: [https://console.aws.amazon.com/cloudwatch](https://console.aws.amazon.com/cloudwatch)
2. Click **Log groups** in the left menu
3. Find `/aws/lambda/dcs-level1-authorizer`
4. Click on the most recent log stream
5. Search for `DCS_ACCESS_DECISION`

You'll see entries like:

```json
{
  "allowed": false,
  "user": "dcs-user-contractor",
  "object": "intel-report.txt",
  "userAttributes": {
    "dcs:clearance": "UNCLASSIFIED",
    "dcs:nationality": "GBR",
    "dcs:saps": ""
  },
  "objectLabels": {
    "dcs:classification": "SECRET",
    "dcs:releasable-to": "GBR,USA,POL",
    "dcs:sap": "NONE",
    "dcs:originator": "POL"
  },
  "denialReasons": [
    "Clearance too low: user has UNCLASSIFIED (level 0), data requires SECRET (level 2)"
  ]
}
```

Every decision - allowed or denied - is logged with the full context: who asked, what they asked for, what attributes they had, what labels the data had, and what the decision was.

## Why this matters

An auditor can answer questions like:

- **Who accessed intel-report.txt?** Search logs for `"object": "intel-report.txt", "allowed": true`
- **What did the contractor try to access?** Search for `"user": "dcs-user-contractor"`
- **Were there any denied requests?** Search for `"allowed": false`
- **Why was a request denied?** The `denialReasons` field explains exactly why

## Set up CloudTrail (optional)

For a more complete audit trail that captures S3 operations (not just our Lambda decisions), set up CloudTrail:

1. Go to **CloudTrail Console**: [https://console.aws.amazon.com/cloudtrail](https://console.aws.amazon.com/cloudtrail)
2. Click **Create trail**
3. **Trail name**: `dcs-level1-audit`
4. **Storage location**: Use existing S3 bucket > `dcs-level1-audit-YOUR-ACCOUNT-ID`
5. Under **Events**:
    - Management events: Enabled
    - Data events: Add S3 > select your data bucket > Read + Write
6. Click **Create trail**

CloudTrail will now log every S3 GetObject, PutObject, and GetObjectTagging call. Combined with our Lambda decision logs, you have a complete picture of who touched what data and why.

!!! info "Audit is non-negotiable in DCS"
    In NATO operations, every access to classified data must be logged and attributable. This isn't optional - it's a core requirement of any DCS system. Even at Level 1, you need to be able to answer "who saw this data and when?"

Next: **[What You Learned](summary.md)** - key takeaways from Lab 1.
