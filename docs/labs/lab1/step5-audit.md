# Step 5: Review the Audit Trail

Even without access control, we have an audit trail. Every time someone requests data through our service, the Lambda logs the access with the object's labels. And CloudTrail logs every S3 operation underneath.

## View Lambda access logs

1. Go to **CloudWatch Console**: [https://console.aws.amazon.com/cloudwatch](https://console.aws.amazon.com/cloudwatch)
2. Click **Log groups** in the left menu
3. Find `/aws/lambda/dcs-lab-data-service`
4. Click on the most recent log stream
5. Search for `DCS_DATA_ACCESS`

You'll see entries like:

```json
{
  "object": "intel-report.txt",
  "labels": {
    "dcs:classification": "SECRET",
    "dcs:releasable-to": "GBR,USA,POL",
    "dcs:sap": "NONE",
    "dcs:originator": "POL"
  }
}
```

Every request is logged with the object name and its labels at the time of access. An auditor can answer "what data was accessed and what were its labels?" but not "who accessed it and should they have been allowed to?" We don't have user identity yet. That comes in Lab 2.

## Set up CloudTrail (optional)

For a more complete audit trail that captures the underlying S3 operations:

1. Go to **CloudTrail Console**: [https://console.aws.amazon.com/cloudtrail](https://console.aws.amazon.com/cloudtrail)
2. Click **Create trail**
3. **Trail name**: `dcs-lab-audit`
4. **Storage location**: Create new S3 bucket (or use an existing one)
5. Under **Events**:
    - Management events: Enabled
    - Data events: Add S3 > select your data bucket > Read + Write
6. Click **Create trail**

CloudTrail will now log every S3 GetObject, PutObject, and PutObjectTagging call, including the label tampering we did in Step 4, if you set this up before that test.

!!! info "Audit is non-negotiable in DCS"
    In NATO operations, every access to classified data must be logged and attributable. This isn't optional. Even at Level 1, you need to be able to answer "what happened to this data?" Lab 2 adds the "who" and "should they have been allowed?" parts.

Next: **[What You Learned](summary.md)**
