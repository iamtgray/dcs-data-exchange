import json
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
iam = boto3.client('iam')

DATA_BUCKET = os.environ['DATA_BUCKET']
CLASSIFICATION_LEVELS = json.loads(os.environ['CLASSIFICATION_LEVELS'])


def get_classification_level(classification):
    """Convert classification string to numeric level for comparison."""
    mapping = {
        'UNCLASSIFIED': 0,
        'OFFICIAL': 1,
        'NATO-RESTRICTED': 1,
        'SECRET': 2,
        'NATO-SECRET': 2,
        'IL-5': 2,
        'IL-6': 2,
        'TOP-SECRET': 3,
        'COSMIC-TOP-SECRET': 3,
        'IL-7': 3,
    }
    return mapping.get(classification.upper(), -1)


def get_user_attributes(username):
    """Get DCS attributes from IAM user tags."""
    response = iam.list_user_tags(UserName=username)
    attrs = {}
    for tag in response['Tags']:
        if tag['Key'].startswith('dcs:'):
            attrs[tag['Key']] = tag['Value']
    return attrs


def get_object_labels(object_key):
    """Get DCS labels from S3 object tags."""
    response = s3.get_object_tagging(Bucket=DATA_BUCKET, Key=object_key)
    labels = {}
    for tag in response['TagSet']:
        if tag['Key'].startswith('dcs:'):
            labels[tag['Key']] = tag['Value']
    return labels


def evaluate_access(user_attrs, object_labels):
    """Evaluate whether user attributes satisfy object label requirements."""
    reasons = []

    user_level = get_classification_level(user_attrs.get('dcs:clearance', 'UNCLASSIFIED'))
    object_level = get_classification_level(object_labels.get('dcs:classification', 'TOP-SECRET'))

    if user_level < object_level:
        reasons.append(
            f"Clearance insufficient: user has {user_attrs.get('dcs:clearance')} "
            f"(level {user_level}), object requires "
            f"{object_labels.get('dcs:classification')} (level {object_level})"
        )

    user_nationality = user_attrs.get('dcs:nationality', '')
    releasable_to = [
        n.strip() for n in object_labels.get('dcs:releasable-to', '').split(',')
    ]

    if releasable_to != ['ALL'] and user_nationality not in releasable_to:
        reasons.append(
            f"Nationality {user_nationality} not in releasable-to list {releasable_to}"
        )

    required_sap = object_labels.get('dcs:sap', 'NONE')
    user_saps = [s.strip() for s in user_attrs.get('dcs:saps', '').split(',') if s.strip()]

    if required_sap != 'NONE' and required_sap not in user_saps:
        reasons.append(
            f"Missing required SAP: {required_sap}. User SAPs: {user_saps}"
        )

    return len(reasons) == 0, reasons


def handler(event, context):
    """Lambda authorizer for DCS Level 1 access control."""
    username = event.get('requestContext', {}).get('identity', {}).get('user', 'unknown')
    object_key = event.get('pathParameters', {}).get('objectKey', '')

    logger.info(f"Access request: user={username}, object={object_key}")

    try:
        user_attrs = get_user_attributes(username)
        object_labels = get_object_labels(object_key)

        authorized, reasons = evaluate_access(user_attrs, object_labels)

        decision_log = {
            'user': username,
            'object': object_key,
            'user_attributes': user_attrs,
            'object_labels': object_labels,
            'authorized': authorized,
            'reasons': reasons,
        }
        logger.info(f"DCS_ACCESS_DECISION: {json.dumps(decision_log)}")

        if authorized:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'authorized': True,
                    'object': object_key,
                    'classification': object_labels.get('dcs:classification'),
                })
            }
        else:
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'authorized': False,
                    'reasons': reasons,
                })
            }

    except Exception as e:
        logger.error(f"Authorization error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Authorization service error'})
        }
