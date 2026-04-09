import json
import re
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

CLASSIFICATION_PATTERNS = {
    'TOP-SECRET': [
        r'\bTOP\s*SECRET\b', r'\bCOSMIC\s*TOP\s*SECRET\b', r'\bTS/SCI\b'
    ],
    'SECRET': [
        r'\bSECRET\b', r'\bNATO\s*SECRET\b', r'\bUK\s*EYES\s*ONLY\b',
        r'\bGRID\s+\d{8}\b',
    ],
    'OFFICIAL': [
        r'\bOFFICIAL\b', r'\bNATO\s*RESTRICTED\b'
    ],
}

SAP_PATTERNS = {
    'WALL': [r'\bWALL\b', r'\bOPERATION\s+WALL\b'],
}


def analyze_content(content):
    """Analyze text content and determine appropriate DCS labels."""
    classification = 'UNCLASSIFIED'
    sap = 'NONE'

    for level in ['TOP-SECRET', 'SECRET', 'OFFICIAL']:
        for pattern in CLASSIFICATION_PATTERNS[level]:
            if re.search(pattern, content, re.IGNORECASE):
                classification = level
                break
        if classification != 'UNCLASSIFIED':
            break

    for sap_name, patterns in SAP_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, content, re.IGNORECASE):
                sap = sap_name
                break

    return classification, sap


def handler(event, context):
    """Auto-label new S3 objects based on content analysis."""
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        logger.info(f"Auto-labeling: bucket={bucket}, key={key}")

        try:
            response = s3.get_object(Bucket=bucket, Key=key, Range='bytes=0-10240')
            content = response['Body'].read().decode('utf-8', errors='ignore')

            classification, sap = analyze_content(content)

            from datetime import datetime
            tags = {
                'dcs:classification': classification,
                'dcs:sap': sap,
                'dcs:labeled-by': 'auto-labeler',
                'dcs:labeled-at': datetime.utcnow().isoformat(),
            }

            existing = s3.get_object_tagging(Bucket=bucket, Key=key)
            existing_tags = {t['Key']: t['Value'] for t in existing['TagSet']}

            if 'dcs:classification' not in existing_tags:
                tag_set = [{'Key': k, 'Value': v} for k, v in {**existing_tags, **tags}.items()]
                s3.put_object_tagging(
                    Bucket=bucket,
                    Key=key,
                    Tagging={'TagSet': tag_set}
                )

                logger.info(f"DCS_AUTO_LABEL: key={key}, classification={classification}, sap={sap}")
            else:
                logger.info(f"DCS_SKIP_LABEL: key={key}, already labeled manually")

        except Exception as e:
            logger.error(f"Auto-labeling error for {key}: {str(e)}")
            try:
                s3.put_object_tagging(
                    Bucket=bucket,
                    Key=key,
                    Tagging={'TagSet': [
                        {'Key': 'dcs:classification', 'Value': 'TOP-SECRET'},
                        {'Key': 'dcs:sap', 'Value': 'NONE'},
                        {'Key': 'dcs:labeled-by', 'Value': 'auto-labeler-failsafe'},
                    ]}
                )
            except Exception:
                pass
