import json
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

avp = boto3.client('verifiedpermissions')
dynamodb = boto3.resource('dynamodb')

POLICY_STORE_ID = os.environ['POLICY_STORE_ID']
table = dynamodb.Table(os.environ['DATA_TABLE'])


def handler(event, context):
    """DCS Level 2 data service with ABAC authorization via Verified Permissions."""
    http_method = event.get('httpMethod', 'GET')
    data_id = event.get('pathParameters', {}).get('dataId', '')

    claims = event.get('requestContext', {}).get('authorizer', {}).get('claims', {})
    user_id = claims.get('sub', 'unknown')
    clearance_level = int(claims.get('custom:clearanceLevel', '0'))
    nationality = claims.get('custom:nationality', '')
    saps_str = claims.get('custom:saps', '')
    saps = [s.strip() for s in saps_str.split(',') if s.strip()]
    organisation = claims.get('custom:organisation', '')

    if http_method == 'GET' and data_id:
        return handle_read(user_id, clearance_level, nationality, saps, organisation, data_id)
    elif http_method == 'GET':
        return handle_list(user_id, clearance_level, nationality, saps, organisation)
    else:
        return response(405, {'error': 'Method not allowed'})


def handle_read(user_id, clearance_level, nationality, saps, org, data_id):
    """Read a specific data object after ABAC authorization."""
    result = table.get_item(Key={'dataId': data_id})
    item = result.get('Item')
    if not item:
        return response(404, {'error': 'Data not found'})

    try:
        avp_response = avp.is_authorized(
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
                'entityId': data_id,
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
                            'organisation': {'string': org},
                        },
                    },
                    {
                        'identifier': {
                            'entityType': 'DCS::DataObject',
                            'entityId': data_id,
                        },
                        'attributes': {
                            'classificationLevel': {'long': int(item.get('classificationLevel', 0))},
                            'releasableTo': {'set': [{'string': n} for n in item.get('releasableTo', [])]},
                            'requiredSap': {'string': item.get('requiredSap', '')},
                            'originator': {'string': item.get('originator', '')},
                        },
                    },
                ]
            },
        )
    except Exception as e:
        logger.error(f"AVP error: {e}")
        return response(500, {'error': 'Authorization service unavailable'})

    decision = avp_response.get('decision', 'DENY')

    logger.info(json.dumps({
        'event': 'DCS_ABAC_DECISION',
        'user': user_id,
        'nationality': nationality,
        'clearanceLevel': clearance_level,
        'dataId': data_id,
        'dataClassification': item.get('classification'),
        'decision': decision,
        'determiningPolicies': [
            p['policyId'] for p in avp_response.get('determiningPolicies', [])
        ],
    }))

    if decision == 'ALLOW':
        return response(200, {
            'dataId': data_id,
            'classification': item.get('classification'),
            'originator': item.get('originator'),
            'payload': item.get('payload'),
            'accessGrantedBy': 'DCS-Level-2-ABAC',
        })
    else:
        return response(403, {
            'authorized': False,
            'dataId': data_id,
            'decision': decision,
            'message': 'Access denied by DCS ABAC policy',
        })


def handle_list(user_id, clearance_level, nationality, saps, org):
    """List all data objects (metadata only, no payloads)."""
    result = table.scan(
        ProjectionExpression='dataId, classification, originator, created, releasableTo, requiredSap'
    )
    items = result.get('Items', [])

    for item in items:
        if 'releasableTo' in item:
            item['releasableTo'] = list(item['releasableTo'])

    return response(200, {
        'count': len(items),
        'items': items,
        'note': 'Listing shows metadata only. Access payload via GET /data/{dataId}'
    })


def response(status, body):
    return {
        'statusCode': status,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        'body': json.dumps(body, default=str),
    }