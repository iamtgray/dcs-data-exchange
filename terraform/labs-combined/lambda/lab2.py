import json
import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
avp = boto3.client('verifiedpermissions')

DATA_BUCKET = os.environ['DATA_BUCKET']
POLICY_STORE_ID = os.environ['POLICY_STORE_ID']

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
    response = s3.get_object_tagging(Bucket=DATA_BUCKET, Key=object_key)
    return {t['Key']: t['Value'] for t in response['TagSet'] if t['Key'].startswith('dcs:')}


def get_object_content(object_key):
    response = s3.get_object(Bucket=DATA_BUCKET, Key=object_key)
    return response['Body'].read().decode('utf-8')


def check_access_avp(user_id, clearance_level, nationality, saps, object_key, labels):
    releasable_raw = labels.get('dcs:releasable-to', '')
    releasable_to = [r.strip() for r in releasable_raw.split() if r.strip()]
    if 'ALL' in releasable_to:
        releasable_to.append(nationality)

    classification = labels.get('dcs:classification', 'TOP-SECRET')
    classification_level = CLASSIFICATION_MAP.get(classification.upper(), 99)

    sap = labels.get('dcs:sap', 'NONE')
    originator = labels.get('dcs:originator', '')

    response = avp.is_authorized(
        policyStoreId=POLICY_STORE_ID,
        principal={'entityType': 'DCS::User', 'entityId': user_id},
        action={'actionType': 'DCS::Action', 'actionId': 'read'},
        resource={'entityType': 'DCS::DataObject', 'entityId': object_key},
        entities={'entityList': [
            {
                'identifier': {'entityType': 'DCS::User', 'entityId': user_id},
                'attributes': {
                    'clearanceLevel': {'long': clearance_level},
                    'nationality': {'string': nationality},
                    'saps': {'set': [{'string': s} for s in saps]},
                },
            },
            {
                'identifier': {'entityType': 'DCS::DataObject', 'entityId': object_key},
                'attributes': {
                    'classificationLevel': {'long': classification_level},
                    'releasableTo': {'set': [{'string': n} for n in releasable_to]},
                    'requiredSap': {'string': sap if sap != 'NONE' else ''},
                    'originator': {'string': originator},
                },
            },
        ]},
    )

    decision = response.get('decision', 'DENY')
    determining = [p['policyId'] for p in response.get('determiningPolicies', [])]
    return decision == 'ALLOW', determining


def lambda_handler(event, context):
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
            return {'statusCode': 400, 'body': json.dumps({'error': 'Must provide objectKey and username'})}

        labels = get_object_labels(object_key)
        allowed, determining_policies = check_access_avp(
            username, clearance_level, nationality, saps, object_key, labels
        )

        if allowed:
            content = get_object_content(object_key)
            result = {
                'object': object_key, 'labels': labels, 'content': content,
                'allowed': True, 'user': username, 'determiningPolicies': determining_policies,
            }
            logger.info(f"DCS_ACCESS_DECISION: {json.dumps({**result, 'content': '(omitted)'})}")
            return {'statusCode': 200, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(result, indent=2)}
        else:
            result = {
                'object': object_key, 'labels': labels,
                'allowed': False, 'user': username, 'determiningPolicies': determining_policies,
            }
            logger.info(f"DCS_ACCESS_DECISION: {json.dumps(result)}")
            return {'statusCode': 403, 'headers': {'Content-Type': 'application/json'}, 'body': json.dumps(result, indent=2)}

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
