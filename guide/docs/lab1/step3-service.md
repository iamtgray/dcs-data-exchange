# Step 3: Build the Data Service

Now we'll build a Lambda function that reads a data object from S3 and returns it along with its labels. This is a simple data service — it doesn't check who's asking or whether they should be allowed to see the data. It just returns the data and its labels together.

Why bother? Because this is what a DCS-aware service looks like at Level 1: when you request data, you get the labels too. The caller (or a downstream system) can then decide what to do with that information. Enforcement comes later, in Lab 2.

## Create the Lambda execution role

The Lambda needs permission to read S3 objects and their tags.

1. Go to **IAM Console**: [https://console.aws.amazon.com/iam](https://console.aws.amazon.com/iam)
2. Click **Roles** > **Create role**
3. **Trusted entity**: AWS service > Lambda
4. Click **Next**
5. Don't attach any managed policies yet — we'll create a custom one
6. **Role name**: `dcs-lab-data-service-role`
7. Click **Create role**

Now add the permissions:

1. Click on the new role `dcs-lab-data-service-role`
2. Click **Add permissions** > **Create inline policy**
3. Switch to the **JSON** editor and paste:

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

4. **Policy name**: `dcs-lab-data-service-policy`
5. Click **Create policy**

## Create the Lambda function

1. Go to **Lambda Console**: [https://console.aws.amazon.com/lambda](https://console.aws.amazon.com/lambda)
2. Click **Create function**
3. **Function name**: `dcs-lab-data-service`
4. **Runtime**: Python 3.12
5. **Execution role**: Use existing role > `dcs-lab-data-service-role`
6. Click **Create function**

## Add the function code

Replace the default code with the following:

```python
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

# Your data bucket name - update this!
DATA_BUCKET = 'dcs-lab-data-YOUR-ACCOUNT-ID'


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


def lambda_handler(event, context):
    """
    Entry point. Expects a JSON body with:
    {
      "objectKey": "intel-report.txt"
    }

    Returns the data content and its DCS labels.
    """
    try:
        body = json.loads(event.get('body', '{}'))
        object_key = body.get('objectKey', '')

        if not object_key:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Must provide objectKey'})
            }

        # Get the data and its labels
        content = get_object_content(object_key)
        labels = get_object_labels(object_key)

        result = {
            'object': object_key,
            'labels': labels,
            'content': content,
        }

        # Log the access
        logger.info(f"DCS_DATA_ACCESS: {json.dumps({'object': object_key, 'labels': labels})}")

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(result, indent=2)
        }

    except s3.exceptions.NoSuchKey:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': f'Object {object_key} not found'})
        }
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

!!! warning "Update the bucket name"
    Change `DATA_BUCKET` on line 11 to your actual bucket name (e.g., `dcs-lab-data-123456789012`).

This is deliberately simple. The function reads an S3 object, reads its tags, and returns both. No access checking, no user attributes, no allow/deny. Every request gets the data.

## Deploy the code

1. Paste the code into the Lambda editor
2. Click **Deploy**
3. Go to **Configuration** > **General configuration** > **Edit**
4. Set **Timeout** to 10 seconds (default 3s may not be enough for S3 reads)
5. Click **Save**

## Add a Function URL (for easy testing)

1. Go to **Configuration** > **Function URL**
2. Click **Create function URL**
3. **Auth type**: NONE (for demo purposes only)
4. Click **Save**
5. Copy the function URL — you'll need it in the next step

!!! danger "Demo only"
    A Function URL with no auth is fine for testing. In production, you'd use API Gateway with proper authentication. But that's exactly the point of this lab — right now, anyone can get any data. Labels are present but not enforced.

Next: **[Step 4: Test the Data Service](step4-test.md)**
