# Step 4: Build the Data Service

Now we'll create the Lambda function that ties everything together: it takes a user's JWT token, extracts their attributes, looks up the data labels, calls Verified Permissions to check the policy, and returns the data or a denial.

## Create the Lambda execution role

1. Go to **IAM Console** > **Roles** > **Create role**
2. **Trusted entity**: AWS service > Lambda
3. Click **Next**
4. **Role name**: `dcs-level2-service-role`
5. Click **Create role**

Add an inline policy:

1. Click the new role > **Add permissions** > **Create inline policy** > JSON editor
2. Paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "verifiedpermissions:IsAuthorized",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/dcs-level2-data"
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

3. **Policy name**: `dcs-level2-service-policy`
4. Click **Create policy**

## Create the Lambda function

1. Go to **Lambda Console** > **Create function**
2. **Function name**: `dcs-level2-data-service`
3. **Runtime**: Python 3.12
4. **Execution role**: Use existing > `dcs-level2-service-role`
5. Click **Create function**

## Add the function code

```python
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

avp = boto3.client('verifiedpermissions')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('dcs-level2-data')

# UPDATE THIS with your Policy Store ID from Step 2
POLICY_STORE_ID = 'YOUR_POLICY_STORE_ID'


def lambda_handler(event, context):
    """Handle data access requests with ABAC authorization."""
    try:
        body = json.loads(event.get('body', '{}'))
        action = body.get('action', 'read')
        data_id = body.get('dataId', '')

        # User attributes (in production, these come from the JWT token)
        user_id = body.get('userId', '')
        clearance_level = int(body.get('clearanceLevel', 0))
        nationality = body.get('nationality', '')
        saps = body.get('saps', [])
        if isinstance(saps, str):
            saps = [s.strip() for s in saps.split(',') if s.strip()]

        if not user_id or not data_id:
            return respond(400, {'error': 'Provide userId and dataId'})

        # Get the data item and its labels from DynamoDB
        result = table.get_item(Key={'dataId': data_id})
        item = result.get('Item')
        if not item:
            return respond(404, {'error': f'Data item {data_id} not found'})

        # Build entity information for Verified Permissions
        releasable_to = list(item.get('releasableTo', set()))
        if 'ALL' in releasable_to:
            # If releasable to ALL, add the user's nationality so the check passes
            releasable_to.append(nationality)

        avp_request = {
            'policyStoreId': POLICY_STORE_ID,
            'principal': {
                'entityType': 'DCS::User',
                'entityId': user_id,
            },
            'action': {
                'actionType': 'DCS::Action',
                'actionId': action,
            },
            'resource': {
                'entityType': 'DCS::DataObject',
                'entityId': data_id,
            },
            'entities': {
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
                            'entityId': data_id,
                        },
                        'attributes': {
                            'classificationLevel': {
                                'long': int(item.get('classificationLevel', 0))
                            },
                            'releasableTo': {
                                'set': [{'string': n} for n in releasable_to]
                            },
                            'requiredSap': {
                                'string': item.get('requiredSap', '')
                            },
                            'originator': {
                                'string': item.get('originator', '')
                            },
                        },
                    },
                ]
            },
        }

        # Call Verified Permissions
        avp_response = avp.is_authorized(**avp_request)
        decision = avp_response.get('decision', 'DENY')

        # Get the policies that determined this decision
        determining = [
            p['policyId']
            for p in avp_response.get('determiningPolicies', [])
        ]

        # Log the decision
        log_entry = {
            'event': 'DCS_ABAC_DECISION',
            'user': user_id,
            'nationality': nationality,
            'clearanceLevel': clearance_level,
            'saps': saps,
            'dataId': data_id,
            'classification': item.get('classification'),
            'decision': decision,
            'determiningPolicies': determining,
        }
        logger.info(json.dumps(log_entry))

        if decision == 'ALLOW':
            return respond(200, {
                'decision': 'ALLOW',
                'dataId': data_id,
                'classification': item.get('classification'),
                'originator': item.get('originator'),
                'payload': item.get('payload'),
                'authorizedBy': determining,
            })
        else:
            return respond(403, {
                'decision': 'DENY',
                'dataId': data_id,
                'classification': item.get('classification'),
                'message': 'Access denied by DCS ABAC policy',
                'evaluatedPolicies': determining,
            })

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return respond(500, {'error': str(e)})


def respond(status, body):
    return {
        'statusCode': status,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        'body': json.dumps(body, default=str),
    }
```

!!! warning "Update the Policy Store ID"
    Replace `YOUR_POLICY_STORE_ID` on line 12 with the ID from Step 2.

## Deploy and configure

1. Paste the code and click **Deploy**
2. Go to **Configuration** > **General** > set **Timeout** to 15 seconds
3. Go to **Configuration** > **Function URL** > **Create function URL** > Auth type: NONE
4. Copy the Function URL

Next: **[Step 5: Test ABAC Scenarios](step5-test.md)**
