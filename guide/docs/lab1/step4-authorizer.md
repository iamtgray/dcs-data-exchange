# Step 4: Build the Access Checker

This is the heart of DCS Level 1. We'll create a Lambda function that:

1. Receives a request: "Can user X access object Y?"
2. Reads the user's attributes (clearance, nationality, SAPs) from their IAM tags
3. Reads the object's labels (classification, releasability, SAP) from its S3 tags
4. Compares them and returns allow or deny

## Create the Lambda execution role

The Lambda needs permission to read IAM user tags and S3 object tags.

1. Go to **IAM Console** > **Roles** > **Create role**
2. **Trusted entity**: AWS service > Lambda
3. Click **Next**
4. Don't attach any managed policies yet - we'll create a custom one
5. **Role name**: `dcs-level1-authorizer-role`
6. Click **Create role**

Now add the permissions:

1. Click on the new role `dcs-level1-authorizer-role`
2. Click **Add permissions** > **Create inline policy**
3. Switch to the **JSON** editor and paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObjectTagging"
      ],
      "Resource": "arn:aws:s3:::dcs-level1-data-*/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:ListUserTags"
      ],
      "Resource": "arn:aws:iam::*:user/dcs-user-*"
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

4. **Policy name**: `dcs-level1-authorizer-policy`
5. Click **Create policy**

## Create the Lambda function

1. Go to **Lambda Console**: [https://console.aws.amazon.com/lambda](https://console.aws.amazon.com/lambda)
2. Click **Create function**
3. **Function name**: `dcs-level1-authorizer`
4. **Runtime**: Python 3.12
5. **Execution role**: Use existing role > `dcs-level1-authorizer-role`
6. Click **Create function**

## Add the function code

Replace the default code with the following. This is the DCS Level 1 access checker:

```python
import json
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
iam = boto3.client('iam')

# Your data bucket name - update this!
DATA_BUCKET = 'dcs-level1-data-YOUR-ACCOUNT-ID'

# Classification levels mapped to numbers for comparison.
# Higher number = higher classification.
# Different nations use different names for the same level.
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


def get_user_attributes(username):
    """Read a user's DCS attributes from their IAM tags."""
    response = iam.list_user_tags(UserName=username)
    attrs = {}
    for tag in response['Tags']:
        if tag['Key'].startswith('dcs:'):
            attrs[tag['Key']] = tag['Value']
    return attrs


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


def check_access(user_attrs, object_labels):
    """
    Compare user attributes against object labels.
    Returns (allowed: bool, reasons: list of strings).
    """
    reasons = []

    # --- Check 1: Classification level ---
    user_clearance = user_attrs.get('dcs:clearance', 'UNCLASSIFIED')
    object_classification = object_labels.get('dcs:classification', 'TOP-SECRET')

    user_level = CLASSIFICATION_MAP.get(user_clearance.upper(), -1)
    object_level = CLASSIFICATION_MAP.get(object_classification.upper(), 99)

    if user_level < object_level:
        reasons.append(
            f"Clearance too low: user has {user_clearance} (level {user_level}), "
            f"data requires {object_classification} (level {object_level})"
        )

    # --- Check 2: Nationality / releasability ---
    user_nationality = user_attrs.get('dcs:nationality', '')
    releasable_to = object_labels.get('dcs:releasable-to', '')
    releasable_list = [r.strip() for r in releasable_to.split(',')]

    if 'ALL' not in releasable_list and user_nationality not in releasable_list:
        reasons.append(
            f"Nationality not allowed: user is {user_nationality}, "
            f"data is releasable to {releasable_list}"
        )

    # --- Check 3: Special Access Program ---
    required_sap = object_labels.get('dcs:sap', 'NONE')
    user_saps = user_attrs.get('dcs:saps', '')
    user_sap_list = [s.strip() for s in user_saps.split(',') if s.strip()]

    if required_sap != 'NONE' and required_sap not in user_sap_list:
        reasons.append(
            f"Missing SAP: data requires {required_sap}, "
            f"user has {user_sap_list if user_sap_list else 'none'}"
        )

    allowed = len(reasons) == 0
    return allowed, reasons


def lambda_handler(event, context):
    """
    Entry point. Expects a JSON body with:
    {
      "username": "dcs-user-gbr-secret",
      "objectKey": "intel-report.txt"
    }
    """
    try:
        body = json.loads(event.get('body', '{}'))
        username = body.get('username', '')
        object_key = body.get('objectKey', '')

        if not username or not object_key:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Must provide username and objectKey'
                })
            }

        # Get attributes and labels
        user_attrs = get_user_attributes(username)
        object_labels = get_object_labels(object_key)

        # Make the access decision
        allowed, reasons = check_access(user_attrs, object_labels)

        # Build the result
        result = {
            'allowed': allowed,
            'user': username,
            'object': object_key,
            'userAttributes': user_attrs,
            'objectLabels': object_labels,
        }
        if not allowed:
            result['denialReasons'] = reasons

        # Log the full decision (this is our DCS audit trail)
        logger.info(f"DCS_ACCESS_DECISION: {json.dumps(result)}")

        status = 200 if allowed else 403
        return {
            'statusCode': status,
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

!!! warning "Update the bucket name"
    Change `DATA_BUCKET` on line 11 to your actual bucket name (e.g., `dcs-level1-data-123456789012`).

## Deploy the code

1. Paste the code into the Lambda editor
2. Click **Deploy**
3. Go to **Configuration** > **General configuration** > **Edit**
4. Set **Timeout** to 10 seconds (default 3s may not be enough)
5. Click **Save**

## Add a Function URL (for easy testing)

Instead of setting up API Gateway, we'll use a Lambda Function URL for quick testing:

1. Go to **Configuration** > **Function URL**
2. Click **Create function URL**
3. **Auth type**: NONE (for demo purposes only)
4. Click **Save**
5. Copy the function URL - you'll need it in Step 5

!!! danger "Demo only"
    A Function URL with no auth is fine for testing. In production, you'd use API Gateway with proper authentication.

!!! abstract "What the assured architecture does differently"
    This authorizer reads S3 tags and trusts them at face value. The **Assured DCS Level 1** authorizer does three things before evaluating access:

    1. Verifies the STANAG 4778 signature, confirming the label hasn't been tampered with since it was signed
    2. Checks data integrity by computing a SHA-256 hash of the S3 object and comparing it to the signed hash, detecting any data modification after labeling
    3. Parses STANAG 4774 XML, extracting classification, releasability, and SAPs from the structured label format

    If either the signature or hash check fails, access is denied regardless of the user's clearance. That's the "assured" part.

Next: **[Step 5: Test Access Decisions](step5-test.md)** - let's see DCS in action.
