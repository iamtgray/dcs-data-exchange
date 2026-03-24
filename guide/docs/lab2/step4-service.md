# Step 4: Add Access Control to the Data Service

Now we'll modify the Lambda from Lab 1. Instead of returning data to anyone who asks, it will check the caller's attributes against the data's labels using Verified Permissions before returning anything.

The Lambda is still plumbing. It reads user attributes from the request, reads data labels from S3 tags, passes both to Verified Permissions, and returns the data or a denial. It has no opinion about what SECRET means or how clearance comparisons work. That's all in the Cedar policies from Step 2.

## Update the Lambda execution role

The Lambda needs two new permissions: calling Verified Permissions and reading S3 object tags (it already has GetObject from Lab 1, but let's make sure GetObjectTagging is there too).

1. Go to **IAM Console** > **Roles** > find `dcs-lab-data-service-role`
2. Click on the inline policy > **Edit**
3. Add these statements to the existing policy:

```json
{
  "Effect": "Allow",
  "Action": "verifiedpermissions:IsAuthorized",
  "Resource": "*"
}
```

The full policy should now look like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectTagging"
      ],
      "Resource": "arn:aws:s3:::dcs-lab-data-*/*"
    },
    {
      "Effect": "Allow",
      "Action": "verifiedpermissions:IsAuthorized",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

4. Click **Save changes**

## Update the Lambda function code

Go to your `dcs-lab-data-service` function in the Lambda console and replace the code with the following. Compare it to the Lab 1 version — the `get_object_labels` and `get_object_content` functions are the same. What's new is `check_access_avp` and the classification mapping.

```python
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
avp = boto3.client('verifiedpermissions')

# Your data bucket name - same as Lab 1
DATA_BUCKET = 'dcs-lab-data-YOUR-ACCOUNT-ID'

# UPDATE THIS with your Policy Store ID from Step 2
POLICY_STORE_ID = 'YOUR_POLICY_STORE_ID'

# Classification levels mapped to numbers for Cedar comparison.
CLASSIFICATION_MAP = {
    'UNCLASSIFIED': 0,
    'OFFICIAL': 1,
    'NATO-RESTRICTED': 1,
    'SECRET': 2,
    'NATO-SECRET': 2,
    'IL-5': 2,
    'IL-6': 2,
    'TOP-SECRET': 3,
    'COSMIC-TOP-SECRET': 3,
}


def get_object_labels(object_key):
    """Read a data object's DCS labels from its S3 tags."""
    response = s3.get_object_tagging(
        Bucket=DATA_BUCKET,
        Key=object_key
    )
    labels = {}
    for tag in response['TagSet']:
        if tag['Key'].startswith('dcs:'):
            labels[tag['Key']] = tag['Value']
    return labels


def get_object_content(object_key):
    """Read the data object's content from S3."""
    response = s3.get_object(
        Bucket=DATA_BUCKET,
        Key=object_key
    )
    return response['Body'].read().decode('utf-8')


def check_access_avp(user_id, clearance_level, nationality, saps, object_key, labels):
    """Ask Verified Permissions whether this access should be allowed."""
    # Parse releasable-to into a set
    releasable_raw = labels.get('dcs:releasable-to', '')
    releasable_to = [r.strip() for r in releasable_raw.split(',') if r.strip()]
    if 'ALL' in releasable_to:
        releasable_to.append(nationality)

    # Map classification string to number
    classification = labels.get('dcs:classification', 'TOP-SECRET')
    classification_level = CLASSIFICATION_MAP.get(classification.upper(), 99)

    sap = labels.get('dcs:sap', 'NONE')
    originator = labels.get('dcs:originator', '')

    response = avp.is_authorized(
        policyStoreId=POLICY_STORE_ID,
        principal={
            'entityType': 'DCS::User',
            'entityId': user_id,
        },
        action={
            'actionType': 'DCS::Action',
            'actionId': 'read',
        },
        resource={
            'entityType': 'DCS::DataObject',
            'entityId': object_key,
        },
        entities={
            'entityList': [
                {
                    'identifier': {
                        'entityType': 'DCS::User',
                        'entityId': user_id,
                    },
                    'attributes': {
                        'clearanceLevel': {'long': clearance_level},
                        'nationality': {'string': nationality},
                        'saps': {'set': [{'string': s} for s in saps]},
                    },
                },
                {
                    'identifier': {
                        'entityType': 'DCS::DataObject',
                        'entityId': object_key,
                    },
                    'attributes': {
                        'classificationLevel': {'long': classification_level},
                        'releasableTo': {'set': [{'string': n} for n in releasable_to]},
                        'requiredSap': {'string': sap if sap != 'NONE' else ''},
                        'originator': {'string': originator},
                    },
                },
            ]
        },
    )

    decision = response.get('decision', 'DENY')
    determining = [p['policyId'] for p in response.get('determiningPolicies', [])]
    return decision == 'ALLOW', determining


def lambda_handler(event, context):
    """
    Entry point. Now expects user attributes alongside the object key:
    {
      "objectKey": "intel-report.txt",
      "username": "uk-analyst-01",
      "clearanceLevel": 2,
      "nationality": "GBR",
      "saps": ["WALL"]
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        object_key = body.get('objectKey', '')
        username = body.get('username', '')
        clearance_level = int(body.get('clearanceLevel', 0))
        nationality = body.get('nationality', '')
        saps = body.get('saps', [])
        if isinstance(saps, str):
            saps = [s.strip() for s in saps.split(',') if s.strip()]

        if not object_key or not username:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Must provide objectKey and username'})
            }

        # Get the data labels from S3 tags (same as Lab 1)
        labels = get_object_labels(object_key)

        # NEW: Check access via Verified Permissions
        allowed, determining_policies = check_access_avp(
            username, clearance_level, nationality, saps, object_key, labels
        )

        if allowed:
            # Get the data content (only if allowed)
            content = get_object_content(object_key)

            result = {
                'object': object_key,
                'labels': labels,
                'content': content,
                'allowed': True,
                'user': username,
                'determiningPolicies': determining_policies,
            }
            logger.info(f"DCS_ACCESS_DECISION: {json.dumps({**result, 'content': '(omitted)'})}")

            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(result, indent=2)
            }
        else:
            result = {
                'object': object_key,
                'labels': labels,
                'allowed': False,
                'user': username,
                'determiningPolicies': determining_policies,
            }
            logger.info(f"DCS_ACCESS_DECISION: {json.dumps(result)}")

            return {
                'statusCode': 403,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(result, indent=2)
            }

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

!!! warning "Update both values"
    - `DATA_BUCKET` on line 12: your bucket name from Lab 1
    - `POLICY_STORE_ID` on line 15: the ID from Step 2

## What changed from Lab 1

Look at what's different:

- The `lambda_handler` now expects `username`, `clearanceLevel`, `nationality`, and `saps` in the request (in production, these would come from a JWT token)
- Before reading the S3 object content, it calls `check_access_avp` to ask Verified Permissions for a decision
- If denied, it returns the labels but not the content — the caller can see what the data is labeled as, but can't read it
- If allowed, it returns everything (same as Lab 1) plus `determiningPolicies` showing which Cedar policy allowed the access

What didn't change: `get_object_labels` and `get_object_content` are identical to Lab 1. The data is still in S3 with the same tags. The only new thing is the policy check in the middle.

## Deploy

1. Paste the updated code and click **Deploy**
2. Make sure the timeout is still 15 seconds (the Verified Permissions call adds latency)

The Function URL from Lab 1 still works — no need to create a new one.

Next: **[Step 5: Test ABAC Scenarios](step5-test.md)**
