"""
DCS Level 1 Assured - STANAG 4774/4778 Authorizer

Verifies cryptographic binding (STANAG 4778) of confidentiality labels
(STANAG 4774) before evaluating access policy. If the binding signature
is invalid or the data hash doesn't match, access is ALWAYS denied
regardless of user clearance.
"""

import json
import hashlib
import base64
import os
import logging
from datetime import datetime, timezone

import boto3
from lxml import etree

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
kms = boto3.client('kms')
iam = boto3.client('iam')
dynamodb = boto3.resource('dynamodb')

DATA_BUCKET = os.environ['DATA_BUCKET']
LABEL_TABLE = os.environ['LABEL_TABLE']
SIGNING_KEY_ID = os.environ['SIGNING_KEY_ID']

table = dynamodb.Table(LABEL_TABLE)

STANAG_NS = 'urn:nato:stanag:4774:confidentialitymetadatalabel:1:0'

CLASSIFICATION_LEVELS = {
    'NATO UNCLASSIFIED': 0,
    'NATO RESTRICTED': 1,
    'NATO CONFIDENTIAL': 2,
    'NATO SECRET': 3,
    'COSMIC TOP SECRET': 4,
    'OFFICIAL': 1,
    'SECRET': 3,
    'TOP SECRET': 4,
    'UNCLASSIFIED': 0,
    'CONFIDENTIAL': 2,
    'IL-5': 3,
    'IL-6': 3,
    'IL-7': 4,
}


def verify_binding(label_xml, data_hash, signature_b64):
    """Verify the STANAG 4778 cryptographic binding."""
    canonical_label = etree.tostring(
        etree.fromstring(label_xml.encode('utf-8')),
        method='c14n2',
    )
    binding_doc = canonical_label + b'\n' + data_hash.encode('utf-8')

    try:
        response = kms.verify(
            KeyId=SIGNING_KEY_ID,
            Message=binding_doc,
            MessageType='RAW',
            Signature=base64.b64decode(signature_b64),
            SigningAlgorithm='RSASSA_PKCS1_V1_5_SHA_256',
        )
        return response['SignatureValid']
    except Exception as e:
        logger.error(f'Signature verification failed: {str(e)}')
        return False


def verify_data_integrity(bucket, key, expected_hash, version_id=None):
    """Verify that the S3 object content matches the signed hash."""
    get_args = {'Bucket': bucket, 'Key': key}
    if version_id and version_id != 'LATEST':
        get_args['VersionId'] = version_id

    response = s3.get_object(**get_args)
    sha256 = hashlib.sha256()
    for chunk in iter(lambda: response['Body'].read(8192), b''):
        sha256.update(chunk)

    actual_hash = sha256.hexdigest()
    return actual_hash == expected_hash


def parse_stanag_4774_label(label_xml):
    """Parse a STANAG 4774 XML label into a structured dict."""
    root = etree.fromstring(label_xml.encode('utf-8'))
    ns = {'s': STANAG_NS}

    result = {
        'policy': '',
        'classification': '',
        'releasable_to': [],
        'saps': [],
        'originator': '',
        'created': '',
    }

    conf_info = root.find('s:ConfidentialityInformation', ns)
    if conf_info is not None:
        policy_el = conf_info.find('s:PolicyIdentifier', ns)
        if policy_el is not None:
            result['policy'] = policy_el.text or ''

        class_el = conf_info.find('s:Classification', ns)
        if class_el is not None:
            result['classification'] = class_el.text or ''

        for category in conf_info.findall('s:Category', ns):
            tag_name = category.get('TagName', '')
            cat_type = category.get('Type', '')
            values = [v.text for v in category.findall('s:CategoryValue', ns) if v.text]

            if tag_name == 'ReleasableTo' and cat_type == 'PERMISSIVE':
                result['releasable_to'] = values
            elif tag_name == 'SpecialAccessProgram' and cat_type == 'RESTRICTIVE':
                result['saps'].extend(values)

    orig_el = root.find('s:Originator', ns)
    if orig_el is not None:
        result['originator'] = orig_el.text or ''

    created_el = root.find('s:CreationDateTime', ns)
    if created_el is not None:
        result['created'] = created_el.text or ''

    return result


def get_user_attributes(username):
    """Get DCS attributes from IAM user tags."""
    response = iam.list_user_tags(UserName=username)
    attrs = {}
    for tag in response['Tags']:
        if tag['Key'].startswith('dcs:'):
            attrs[tag['Key']] = tag['Value']
    return attrs


def evaluate_access(user_attrs, label):
    """Evaluate whether user attributes satisfy STANAG 4774 label requirements."""
    reasons = []

    user_clearance = user_attrs.get('dcs:clearance', 'NATO UNCLASSIFIED')
    object_classification = label['classification']

    user_level = CLASSIFICATION_LEVELS.get(user_clearance, -1)
    object_level = CLASSIFICATION_LEVELS.get(object_classification, 99)

    if user_level < object_level:
        reasons.append(
            f'Classification insufficient: user has {user_clearance} '
            f'(level {user_level}), object requires '
            f'{object_classification} (level {object_level})'
        )

    user_nationality = user_attrs.get('dcs:nationality', '')
    releasable_to = label['releasable_to']

    if releasable_to and 'ALL' not in releasable_to:
        if user_nationality not in releasable_to:
            reasons.append(
                f'Nationality {user_nationality} not in releasable-to list {releasable_to}'
            )

    required_saps = label['saps']
    user_saps = [s.strip() for s in user_attrs.get('dcs:saps', '').split(',') if s.strip()]

    for sap in required_saps:
        if sap not in user_saps:
            reasons.append(f'Missing required SAP: {sap}. User SAPs: {user_saps}')

    return len(reasons) == 0, reasons


def handler(event, context):
    """Lambda authorizer: verify STANAG 4778 binding, then evaluate access."""
    username = event.get('requestContext', {}).get('identity', {}).get('user', 'unknown')
    object_key = event.get('pathParameters', {}).get('objectKey', '')
    version_id = event.get('queryStringParameters', {}).get('versionId', 'LATEST')

    logger.info(f'Access request: user={username}, object={object_key}')

    try:
        response = table.get_item(Key={
            'object_key': object_key,
            'object_version': version_id,
        })

        if 'Item' not in response:
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'authorized': False,
                    'reason': 'No STANAG 4774 label found for this object.',
                })
            }

        item = response['Item']
        label_xml = item['label_xml']
        data_hash = item['data_hash']
        signature = item['binding_signature']

        binding_valid = verify_binding(label_xml, data_hash, signature)
        if not binding_valid:
            logger.critical(json.dumps({
                'event': 'DCS_BINDING_VERIFICATION_FAILED',
                'object_key': object_key,
                'version': version_id,
                'user': username,
                'alert': 'POSSIBLE LABEL TAMPERING',
            }))
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'authorized': False,
                    'reason': 'STANAG 4778 binding verification failed.',
                })
            }

        data_intact = verify_data_integrity(DATA_BUCKET, object_key, data_hash, version_id)
        if not data_intact:
            logger.critical(json.dumps({
                'event': 'DCS_DATA_INTEGRITY_FAILED',
                'object_key': object_key,
                'version': version_id,
                'user': username,
                'alert': 'DATA MODIFIED AFTER LABELING',
            }))
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'authorized': False,
                    'reason': 'Data integrity check failed. Re-labeling required.',
                })
            }

        label = parse_stanag_4774_label(label_xml)
        user_attrs = get_user_attributes(username)
        authorized, reasons = evaluate_access(user_attrs, label)

        decision_log = {
            'event': 'DCS_ACCESS_DECISION',
            'user': username,
            'object': object_key,
            'version': version_id,
            'user_attributes': user_attrs,
            'label': label,
            'binding_verified': True,
            'data_integrity_verified': True,
            'authorized': authorized,
            'reasons': reasons,
            'timestamp': datetime.now(timezone.utc).isoformat(),
        }
        logger.info(f'DCS_ACCESS_DECISION: {json.dumps(decision_log)}')

        if authorized:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'authorized': True,
                    'object': object_key,
                    'classification': label['classification'],
                    'policy': label['policy'],
                    'binding_verified': True,
                    'data_integrity_verified': True,
                })
            }
        else:
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'authorized': False,
                    'reasons': reasons,
                    'binding_verified': True,
                    'data_integrity_verified': True,
                })
            }

    except Exception as e:
        logger.error(f'Authorization error: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Authorization service error'})
        }
