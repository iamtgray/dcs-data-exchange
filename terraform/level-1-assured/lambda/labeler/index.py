"""
DCS Level 1 Assured - STANAG 4774/4778 Label Service

Creates NATO STANAG 4774 confidentiality labels and binds them to S3 objects
using STANAG 4778 cryptographic binding (digital signatures via AWS KMS).
"""

import json
import hashlib
import base64
import os
import re
import logging
from datetime import datetime, timezone

import boto3
from lxml import etree

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
kms = boto3.client('kms')
dynamodb = boto3.resource('dynamodb')

DATA_BUCKET = os.environ['DATA_BUCKET']
LABEL_TABLE = os.environ['LABEL_TABLE']
SIGNING_KEY_ID = os.environ['SIGNING_KEY_ID']

table = dynamodb.Table(LABEL_TABLE)

STANAG_NS = 'urn:nato:stanag:4774:confidentialitymetadatalabel:1:0'
STANAG_POLICY_BASE = f'{STANAG_NS}:policy'

CLASSIFICATION_PATTERNS = {
    'COSMIC TOP SECRET': [
        r'\bCOSMIC\s+TOP\s+SECRET\b', r'\bCTS\b', r'\bTS/SCI\b'
    ],
    'NATO SECRET': [
        r'\bNATO\s+SECRET\b', r'\bNS\b(?!\w)', r'\bSECRET\b',
        r'\bUK\s+EYES\s+ONLY\b', r'\bGRID\s+\d{6,8}\b',
    ],
    'NATO CONFIDENTIAL': [
        r'\bNATO\s+CONFIDENTIAL\b', r'\bNC\b(?!\w)',
    ],
    'NATO RESTRICTED': [
        r'\bNATO\s+RESTRICTED\b', r'\bNR\b(?!\w)',
        r'\bOFFICIAL\b',
    ],
}

SAP_PATTERNS = {
    'WALL': [r'\bWALL\b', r'\bOPERATION\s+WALL\b'],
}


def build_stanag_4774_label(classification, policy, releasable_to, saps, originator):
    """Build a STANAG 4774 ConfidentialityLabel XML element."""
    nsmap = {None: STANAG_NS}
    root = etree.Element(f'{{{STANAG_NS}}}ConfidentialityLabel', nsmap=nsmap)
    conf_info = etree.SubElement(root, f'{{{STANAG_NS}}}ConfidentialityInformation')

    policy_id = etree.SubElement(conf_info, f'{{{STANAG_NS}}}PolicyIdentifier')
    policy_id.text = f'{STANAG_POLICY_BASE}:{policy}'

    classification_el = etree.SubElement(conf_info, f'{{{STANAG_NS}}}Classification')
    classification_el.text = classification

    if releasable_to:
        rel_cat = etree.SubElement(conf_info, f'{{{STANAG_NS}}}Category')
        rel_cat.set('TagName', 'ReleasableTo')
        rel_cat.set('Type', 'PERMISSIVE')
        for nation in releasable_to:
            val = etree.SubElement(rel_cat, f'{{{STANAG_NS}}}CategoryValue')
            val.text = nation

    for sap in saps:
        if sap and sap != 'NONE':
            sap_cat = etree.SubElement(conf_info, f'{{{STANAG_NS}}}Category')
            sap_cat.set('TagName', 'SpecialAccessProgram')
            sap_cat.set('Type', 'RESTRICTIVE')
            sap_val = etree.SubElement(sap_cat, f'{{{STANAG_NS}}}CategoryValue')
            sap_val.text = sap

    created = etree.SubElement(root, f'{{{STANAG_NS}}}CreationDateTime')
    created.text = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    orig = etree.SubElement(root, f'{{{STANAG_NS}}}Originator')
    orig.text = originator

    return root


def canonicalize_label(label_element):
    """Produce the canonical (C14N) serialization of the label XML."""
    return etree.tostring(label_element, method='c14n2')


def compute_data_hash(bucket, key, version_id=None):
    """Compute SHA-256 hash of the S3 object content."""
    get_args = {'Bucket': bucket, 'Key': key}
    if version_id:
        get_args['VersionId'] = version_id
    response = s3.get_object(**get_args)
    sha256 = hashlib.sha256()
    for chunk in iter(lambda: response['Body'].read(8192), b''):
        sha256.update(chunk)
    return sha256.hexdigest()


def create_binding_document(canonical_label, data_hash):
    """Create the STANAG 4778 binding document."""
    return canonical_label + b'\n' + data_hash.encode('utf-8')


def sign_binding(binding_document):
    """Sign the binding document using KMS asymmetric key."""
    response = kms.sign(
        KeyId=SIGNING_KEY_ID,
        Message=binding_document,
        MessageType='RAW',
        SigningAlgorithm='RSASSA_PKCS1_V1_5_SHA_256',
    )
    return base64.b64encode(response['Signature']).decode('utf-8')


def analyze_content(content):
    """Analyze text content to determine classification and SAPs."""
    classification = 'NATO UNCLASSIFIED'
    saps = []

    for level in ['COSMIC TOP SECRET', 'NATO SECRET', 'NATO CONFIDENTIAL', 'NATO RESTRICTED']:
        for pattern in CLASSIFICATION_PATTERNS[level]:
            if re.search(pattern, content, re.IGNORECASE):
                classification = level
                break
        if classification != 'NATO UNCLASSIFIED':
            break

    for sap_name, patterns in SAP_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, content, re.IGNORECASE):
                saps.append(sap_name)
                break

    return classification, saps


def handler(event, context):
    """Lambda handler: create STANAG 4774 label and 4778 binding for new S3 objects."""
    detail = event.get('detail', {})
    bucket = detail.get('bucket', {}).get('name', DATA_BUCKET)
    key = detail.get('object', {}).get('key', '')
    version_id = detail.get('object', {}).get('version-id', 'LATEST')

    logger.info(f'Labeling: bucket={bucket}, key={key}, version={version_id}')

    try:
        get_args = {'Bucket': bucket, 'Key': key}
        if version_id and version_id != 'LATEST':
            get_args['VersionId'] = version_id
        response = s3.get_object(**{**get_args, 'Range': 'bytes=0-10240'})
        content = response['Body'].read().decode('utf-8', errors='ignore')

        head = s3.head_object(**get_args)
        user_metadata = head.get('Metadata', {})
        explicit_classification = user_metadata.get('dcs-classification')
        explicit_releasable = user_metadata.get('dcs-releasable-to', '')
        explicit_originator = user_metadata.get('dcs-originator', 'UNKNOWN')
        explicit_policy = user_metadata.get('dcs-policy', 'NATO')

        if explicit_classification:
            classification = explicit_classification
            saps = [s.strip() for s in user_metadata.get('dcs-saps', '').split(',') if s.strip()]
        else:
            classification, saps = analyze_content(content)

        releasable_to = [
            n.strip() for n in explicit_releasable.split(',') if n.strip()
        ] if explicit_releasable else ['ALL']

        label_element = build_stanag_4774_label(
            classification=classification,
            policy=explicit_policy,
            releasable_to=releasable_to,
            saps=saps,
            originator=explicit_originator,
        )

        canonical_label = canonicalize_label(label_element)
        label_xml_str = canonical_label.decode('utf-8')
        data_hash = compute_data_hash(bucket, key, version_id if version_id != 'LATEST' else None)
        binding_doc = create_binding_document(canonical_label, data_hash)
        signature = sign_binding(binding_doc)

        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        table.put_item(Item={
            'object_key': key,
            'object_version': version_id,
            'label_xml': label_xml_str,
            'data_hash': data_hash,
            'binding_signature': signature,
            'signing_key_arn': f'arn:aws:kms:{os.environ["AWS_REGION"]}:'
                               f'{boto3.client("sts").get_caller_identity()["Account"]}'
                               f':key/{SIGNING_KEY_ID}',
            'signed_at': now,
            'signed_by': context.invoked_function_arn,
            'label_version': 1,
            'classification': classification,
            'releasable_to': set(releasable_to) if releasable_to != ['ALL'] else {'ALL'},
            'originator': explicit_originator,
        })

        logger.info(json.dumps({
            'event': 'DCS_LABEL_CREATED',
            'object_key': key,
            'version': version_id,
            'classification': classification,
            'releasable_to': releasable_to,
            'saps': saps,
            'data_hash': data_hash,
            'signed_at': now,
        }))

        return {
            'statusCode': 200,
            'body': json.dumps({
                'labeled': True,
                'object_key': key,
                'classification': classification,
            })
        }

    except Exception as e:
        logger.error(f'Labeling error for {key}: {str(e)}')
        try:
            fail_label = build_stanag_4774_label(
                classification='COSMIC TOP SECRET',
                policy='NATO',
                releasable_to=[],
                saps=[],
                originator='SYSTEM-FAILSAFE',
            )
            canonical = canonicalize_label(fail_label)
            data_hash = 'UNKNOWN-HASH-FAILSAFE'
            binding_doc = create_binding_document(canonical, data_hash)
            signature = sign_binding(binding_doc)

            table.put_item(Item={
                'object_key': key,
                'object_version': version_id,
                'label_xml': canonical.decode('utf-8'),
                'data_hash': data_hash,
                'binding_signature': signature,
                'signing_key_arn': SIGNING_KEY_ID,
                'signed_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
                'signed_by': 'FAILSAFE',
                'label_version': 1,
                'classification': 'COSMIC TOP SECRET',
                'releasable_to': set(),
                'originator': 'SYSTEM-FAILSAFE',
            })
        except Exception:
            logger.critical(f'FAILSAFE labeling also failed for {key}')

        raise
