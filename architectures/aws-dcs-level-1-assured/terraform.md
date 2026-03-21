# Terraform Reference - Assured DCS Level 1: STANAG-Compliant Labeling

## Overview

This document provides the Terraform configuration and Lambda code for the Assured DCS Level 1 architecture. It implements STANAG 4774 label syntax and STANAG 4778 cryptographic binding using AWS-native services.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- Python 3.12 runtime (for Lambda functions)

## Directory Structure

```
terraform/
  main.tf              # Provider and backend config
  variables.tf         # Input variables
  s3.tf                # Data bucket and audit bucket
  dynamodb.tf          # Label store table with GSIs
  kms.tf               # Asymmetric signing key
  lambda-labeler.tf    # STANAG 4774/4778 label creation
  lambda-authorizer.tf # Label verification and access control
  api-gateway.tf       # API Gateway configuration
  iam.tf               # IAM roles for simulated users
  cloudtrail.tf        # Audit logging
  eventbridge.tf       # S3 -> Lambda trigger
  outputs.tf           # Outputs
  lambda/
    labeler/
      index.py         # STANAG 4774 label creation + 4778 binding
      requirements.txt # lxml dependency
    authorizer/
      index.py         # Signature verification + access control
      requirements.txt
```

## Core Terraform Configuration

### main.tf
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "dcs-level-1-assured"
      Environment = "demo"
      ManagedBy   = "terraform"
    }
  }
}
```

### variables.tf
```hcl
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"  # London - appropriate for UK/NATO context
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dcs-l1-assured"
}

variable "nato_classifications" {
  description = "Valid NATO classification levels (ordered lowest to highest)"
  type        = list(string)
  default     = [
    "NATO UNCLASSIFIED",
    "NATO RESTRICTED",
    "NATO CONFIDENTIAL",
    "NATO SECRET",
    "COSMIC TOP SECRET"
  ]
}

variable "gbr_classifications" {
  description = "Valid UK national classification levels"
  type        = list(string)
  default     = ["OFFICIAL", "SECRET", "TOP SECRET"]
}

variable "valid_nationalities" {
  description = "Valid nationality codes for releasability"
  type        = list(string)
  default     = ["GBR", "USA", "POL", "DEU", "FRA", "CAN"]
}
```

### kms.tf - Asymmetric Signing Key (STANAG 4778)
```hcl
# This key provides the cryptographic foundation for STANAG 4778 metadata binding.
# The private key never leaves the KMS HSM. The public key can be exported for
# external/offline verification by coalition partners.
resource "aws_kms_key" "label_signing" {
  description              = "DCS Level 1 - STANAG 4778 label binding signing key"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_2048"
  deletion_window_in_days  = 30
  enable_key_rotation      = false  # Asymmetric keys don't support auto-rotation

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RootAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "LabelServiceSign"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.labeler_role.arn }
        Action    = ["kms:Sign", "kms:GetPublicKey"]
        Resource  = "*"
      },
      {
        Sid       = "AuthorizerVerify"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.authorizer_role.arn }
        Action    = ["kms:Verify", "kms:GetPublicKey"]
        Resource  = "*"
      }
    ]
  })

  tags = {
    Purpose = "STANAG-4778-binding"
  }
}

resource "aws_kms_alias" "label_signing" {
  name          = "alias/${var.project_name}-label-signing"
  target_key_id = aws_kms_key.label_signing.key_id
}
```

### dynamodb.tf - Label Store
```hcl
# The label store holds STANAG 4774 XML labels with their STANAG 4778
# cryptographic bindings. This replaces S3 tags/sidecar objects with a
# queryable, access-controlled metadata store.
resource "aws_dynamodb_table" "labels" {
  name         = "${var.project_name}-labels"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "object_key"
  range_key    = "object_version"

  attribute {
    name = "object_key"
    type = "S"
  }

  attribute {
    name = "object_version"
    type = "S"
  }

  attribute {
    name = "classification"
    type = "S"
  }

  attribute {
    name = "originator"
    type = "S"
  }

  # Query all objects at a given classification level
  global_secondary_index {
    name            = "classification-index"
    hash_key        = "classification"
    range_key       = "object_key"
    projection_type = "ALL"
  }

  # Query all objects by originating nation
  global_secondary_index {
    name            = "originator-index"
    hash_key        = "originator"
    range_key       = "object_key"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Purpose = "STANAG-4774-label-store"
  }
}
```

### s3.tf - Data Bucket
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${var.project_name}-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable EventBridge notifications for auto-labeling
resource "aws_s3_bucket_notification" "data" {
  bucket      = aws_s3_bucket.data.id
  eventbridge = true
}

# Audit bucket for CloudTrail
resource "aws_s3_bucket" "audit" {
  bucket = "${var.project_name}-audit-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_caller_identity" "current" {}
```

### iam.tf - Simulated Coalition Users
```hcl
# UK user with SECRET clearance
resource "aws_iam_user" "uk_secret" {
  name = "${var.project_name}-user-gbr-secret"
  tags = {
    "dcs:clearance"    = "SECRET"
    "dcs:nationality"  = "GBR"
    "dcs:saps"         = "WALL"
    "dcs:organisation" = "UK-MOD"
    "dcs:policy"       = "NATO"  # Which classification scheme to evaluate against
  }
}

# Polish user with NATO SECRET clearance
resource "aws_iam_user" "pol_secret" {
  name = "${var.project_name}-user-pol-ns"
  tags = {
    "dcs:clearance"    = "NATO SECRET"
    "dcs:nationality"  = "POL"
    "dcs:saps"         = ""
    "dcs:organisation" = "PL-MON"
    "dcs:policy"       = "NATO"
  }
}

# US user with SECRET clearance
resource "aws_iam_user" "us_secret" {
  name = "${var.project_name}-user-usa-secret"
  tags = {
    "dcs:clearance"    = "SECRET"
    "dcs:nationality"  = "USA"
    "dcs:saps"         = "WALL"
    "dcs:organisation" = "US-DOD"
    "dcs:policy"       = "NATO"
  }
}

# Unclassified contractor
resource "aws_iam_user" "contractor" {
  name = "${var.project_name}-user-contractor"
  tags = {
    "dcs:clearance"    = "NATO UNCLASSIFIED"
    "dcs:nationality"  = "GBR"
    "dcs:saps"         = ""
    "dcs:organisation" = "CONTRACTOR"
    "dcs:policy"       = "NATO"
  }
}

# API invoke permissions for all users
resource "aws_iam_policy" "api_invoke" {
  name = "${var.project_name}-api-invoke"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "${aws_api_gateway_rest_api.dcs.execution_arn}/*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "uk_api" {
  user       = aws_iam_user.uk_secret.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "pol_api" {
  user       = aws_iam_user.pol_secret.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "us_api" {
  user       = aws_iam_user.us_secret.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "contractor_api" {
  user       = aws_iam_user.contractor.name
  policy_arn = aws_iam_policy.api_invoke.arn
}
```

### eventbridge.tf - S3 to Lambda Trigger
```hcl
# Trigger labeling when objects are uploaded to S3
resource "aws_cloudwatch_event_rule" "s3_put" {
  name        = "${var.project_name}-s3-put"
  description = "Trigger label creation on S3 PutObject"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.data.id] }
    }
  })
}

resource "aws_cloudwatch_event_target" "labeler" {
  rule      = aws_cloudwatch_event_rule.s3_put.name
  target_id = "labeler"
  arn       = aws_lambda_function.labeler.arn
}

resource "aws_lambda_permission" "eventbridge_labeler" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.labeler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_put.arn
}
```

### lambda-labeler.tf
```hcl
resource "aws_lambda_function" "labeler" {
  function_name = "${var.project_name}-labeler"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.labeler.output_path
  role          = aws_iam_role.labeler_role.arn
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      DATA_BUCKET    = aws_s3_bucket.data.id
      LABEL_TABLE    = aws_dynamodb_table.labels.name
      SIGNING_KEY_ID = aws_kms_key.label_signing.key_id
    }
  }

  layers = [aws_lambda_layer_version.lxml_layer.arn]
}

data "archive_file" "labeler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/labeler"
  output_path = "${path.module}/lambda/labeler.zip"
}

# lxml Lambda layer (pre-built for Amazon Linux 2023 / Python 3.12)
# In production, build this from the lxml wheel for the Lambda runtime.
# See: https://github.com/XML-Security/signxml for the signxml library.
resource "aws_lambda_layer_version" "lxml_layer" {
  filename            = "${path.module}/lambda/layers/lxml-layer.zip"
  layer_name          = "${var.project_name}-lxml"
  compatible_runtimes = ["python3.12"]
  description         = "lxml XML processing library for STANAG 4774 label generation"
}

resource "aws_iam_role" "labeler_role" {
  name = "${var.project_name}-labeler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "labeler_policy" {
  name = "${var.project_name}-labeler-policy"
  role = aws_iam_role.labeler_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadS3Data"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Sid      = "WriteLabelStore"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.labels.arn
      },
      {
        Sid      = "SignLabels"
        Effect   = "Allow"
        Action   = ["kms:Sign"]
        Resource = aws_kms_key.label_signing.arn
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
```

### lambda-authorizer.tf
```hcl
resource "aws_lambda_function" "authorizer" {
  function_name = "${var.project_name}-authorizer"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.authorizer.output_path
  role          = aws_iam_role.authorizer_role.arn
  timeout       = 15
  memory_size   = 512

  environment {
    variables = {
      DATA_BUCKET    = aws_s3_bucket.data.id
      LABEL_TABLE    = aws_dynamodb_table.labels.name
      SIGNING_KEY_ID = aws_kms_key.label_signing.key_id
    }
  }

  layers = [aws_lambda_layer_version.lxml_layer.arn]
}

data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/authorizer"
  output_path = "${path.module}/lambda/authorizer.zip"
}

resource "aws_iam_role" "authorizer_role" {
  name = "${var.project_name}-authorizer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "authorizer_policy" {
  name = "${var.project_name}-authorizer-policy"
  role = aws_iam_role.authorizer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadS3Data"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Sid      = "ReadLabelStore"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = [
          aws_dynamodb_table.labels.arn,
          "${aws_dynamodb_table.labels.arn}/index/*"
        ]
      },
      {
        Sid      = "VerifySignatures"
        Effect   = "Allow"
        Action   = ["kms:Verify", "kms:GetPublicKey"]
        Resource = aws_kms_key.label_signing.arn
      },
      {
        Sid      = "ReadUserTags"
        Effect   = "Allow"
        Action   = ["iam:GetUser", "iam:ListUserTags"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.project_name}-*"
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
```

Note the separation of concerns in IAM:
- The labeler can `kms:Sign` but cannot `kms:Verify`; it creates bindings
- The authorizer can `kms:Verify` but cannot `kms:Sign`; it validates bindings
- The labeler can write to DynamoDB but the authorizer can only read
- Neither Lambda has permissions to modify the KMS key policy itself

### cloudtrail.tf
```hcl
resource "aws_cloudtrail" "dcs_audit" {
  name                          = "${var.project_name}-audit-trail"
  s3_bucket_name                = aws_s3_bucket.audit.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.data.arn}/"]
    }

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = [aws_dynamodb_table.labels.arn]
    }
  }
}
```

## Lambda Label Service Code

### lambda/labeler/index.py

This Lambda creates STANAG 4774 XML labels and STANAG 4778 cryptographic bindings.

```python
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

# STANAG 4774 namespace
STANAG_NS = 'urn:nato:stanag:4774:confidentialitymetadatalabel:1:0'
STANAG_POLICY_BASE = f'{STANAG_NS}:policy'

# Classification indicators for auto-labeling (simplified for demonstration)
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


def build_stanag_4774_label(
    classification: str,
    policy: str,
    releasable_to: list[str],
    saps: list[str],
    originator: str,
) -> etree._Element:
    """
    Build a STANAG 4774 ConfidentialityLabel XML element.

    This follows the ADatP-4774 schema: PolicyIdentifier, Classification,
    and Category elements within ConfidentialityInformation.
    """
    nsmap = {None: STANAG_NS}

    root = etree.Element(f'{{{STANAG_NS}}}ConfidentialityLabel', nsmap=nsmap)

    conf_info = etree.SubElement(root, f'{{{STANAG_NS}}}ConfidentialityInformation')

    # PolicyIdentifier - specifies which classification scheme
    policy_id = etree.SubElement(conf_info, f'{{{STANAG_NS}}}PolicyIdentifier')
    policy_id.text = f'{STANAG_POLICY_BASE}:{policy}'

    # Classification level
    classification_el = etree.SubElement(conf_info, f'{{{STANAG_NS}}}Classification')
    classification_el.text = classification

    # Releasability (PERMISSIVE category - user must match at least one)
    if releasable_to:
        rel_cat = etree.SubElement(conf_info, f'{{{STANAG_NS}}}Category')
        rel_cat.set('TagName', 'ReleasableTo')
        rel_cat.set('Type', 'PERMISSIVE')
        for nation in releasable_to:
            val = etree.SubElement(rel_cat, f'{{{STANAG_NS}}}CategoryValue')
            val.text = nation

    # Special Access Programs (RESTRICTIVE category - user must hold all)
    for sap in saps:
        if sap and sap != 'NONE':
            sap_cat = etree.SubElement(conf_info, f'{{{STANAG_NS}}}Category')
            sap_cat.set('TagName', 'SpecialAccessProgram')
            sap_cat.set('Type', 'RESTRICTIVE')
            sap_val = etree.SubElement(sap_cat, f'{{{STANAG_NS}}}CategoryValue')
            sap_val.text = sap

    # Creation timestamp
    created = etree.SubElement(root, f'{{{STANAG_NS}}}CreationDateTime')
    created.text = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # Originator
    orig = etree.SubElement(root, f'{{{STANAG_NS}}}Originator')
    orig.text = originator

    return root


def canonicalize_label(label_element: etree._Element) -> bytes:
    """
    Produce the canonical (C14N) serialization of the label XML.

    Canonical XML ensures that logically equivalent XML documents produce
    identical byte sequences, which is essential for signature verification.
    This is the same canonicalization used in XMLDSig (W3C XML Signature).
    """
    return etree.tostring(label_element, method='c14n2')


def compute_data_hash(bucket: str, key: str, version_id: str = None) -> str:
    """Compute SHA-256 hash of the S3 object content."""
    get_args = {'Bucket': bucket, 'Key': key}
    if version_id:
        get_args['VersionId'] = version_id

    response = s3.get_object(**get_args)
    sha256 = hashlib.sha256()
    for chunk in iter(lambda: response['Body'].read(8192), b''):
        sha256.update(chunk)
    return sha256.hexdigest()


def create_binding_document(canonical_label: bytes, data_hash: str) -> bytes:
    """
    Create the binding document that ties the label to the data.

    This is the STANAG 4778 binding: the concatenation of the canonical
    label XML and the data hash, which is then signed. Any modification
    to either the label or the data will invalidate the signature.
    """
    return canonical_label + b'\n' + data_hash.encode('utf-8')


def sign_binding(binding_document: bytes) -> str:
    """Sign the binding document using KMS asymmetric key."""
    response = kms.sign(
        KeyId=SIGNING_KEY_ID,
        Message=binding_document,
        MessageType='RAW',
        SigningAlgorithm='RSASSA_PKCS1_V1_5_SHA_256',
    )
    return base64.b64encode(response['Signature']).decode('utf-8')


def analyze_content(content: str) -> tuple[str, list[str]]:
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
    """
    Lambda handler: create STANAG 4774 label and 4778 binding for new S3 objects.

    Triggered by EventBridge on S3 PutObject events.
    """
    detail = event.get('detail', {})
    bucket = detail.get('bucket', {}).get('name', DATA_BUCKET)
    key = detail.get('object', {}).get('key', '')
    version_id = detail.get('object', {}).get('version-id', 'LATEST')

    logger.info(f'Labeling: bucket={bucket}, key={key}, version={version_id}')

    try:
        # 1. Read object content for analysis (first 10KB)
        get_args = {'Bucket': bucket, 'Key': key}
        if version_id and version_id != 'LATEST':
            get_args['VersionId'] = version_id
        response = s3.get_object(**get_args, Range='bytes=0-10240')
        content = response['Body'].read().decode('utf-8', errors='ignore')

        # 2. Check for explicit classification in S3 user-defined metadata
        head = s3.head_object(**{k: v for k, v in get_args.items()})
        user_metadata = head.get('Metadata', {})
        explicit_classification = user_metadata.get('dcs-classification')
        explicit_releasable = user_metadata.get('dcs-releasable-to', '')
        explicit_originator = user_metadata.get('dcs-originator', 'UNKNOWN')
        explicit_policy = user_metadata.get('dcs-policy', 'NATO')

        # 3. Determine classification (explicit overrides auto-detection)
        if explicit_classification:
            classification = explicit_classification
            saps = [s.strip() for s in user_metadata.get('dcs-saps', '').split(',') if s.strip()]
        else:
            classification, saps = analyze_content(content)

        releasable_to = [
            n.strip() for n in explicit_releasable.split(',') if n.strip()
        ] if explicit_releasable else ['ALL']

        # 4. Build STANAG 4774 label
        label_element = build_stanag_4774_label(
            classification=classification,
            policy=explicit_policy,
            releasable_to=releasable_to,
            saps=saps,
            originator=explicit_originator,
        )

        # 5. Canonicalize label XML
        canonical_label = canonicalize_label(label_element)
        label_xml_str = canonical_label.decode('utf-8')

        # 6. Compute SHA-256 hash of the full S3 object
        data_hash = compute_data_hash(bucket, key, version_id if version_id != 'LATEST' else None)

        # 7. Create and sign the STANAG 4778 binding
        binding_doc = create_binding_document(canonical_label, data_hash)
        signature = sign_binding(binding_doc)

        # 8. Store in DynamoDB
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
            # Denormalized fields for GSI queries
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
        # Fail secure: label as highest classification
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
```

## Lambda Authorizer Code

### lambda/authorizer/index.py

This Lambda verifies STANAG 4778 bindings and evaluates access policy against STANAG 4774 labels.

```python
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

# Classification hierarchy for cross-scheme comparison.
# Maps classification strings to numeric levels for dominance comparison.
# In production, this would be a configurable policy engine.
CLASSIFICATION_LEVELS = {
    # NATO classifications
    'NATO UNCLASSIFIED': 0,
    'NATO RESTRICTED': 1,
    'NATO CONFIDENTIAL': 2,
    'NATO SECRET': 3,
    'COSMIC TOP SECRET': 4,
    # UK national classifications (mapped to NATO equivalents)
    'OFFICIAL': 1,
    'SECRET': 3,
    'TOP SECRET': 4,
    # US classifications
    'UNCLASSIFIED': 0,
    'CONFIDENTIAL': 2,
    # US impact levels (approximate mapping)
    'IL-5': 3,
    'IL-6': 3,
    'IL-7': 4,
}


def verify_binding(label_xml: str, data_hash: str, signature_b64: str) -> bool:
    """
    Verify the STANAG 4778 cryptographic binding.

    Reconstructs the binding document from the label XML and data hash,
    then verifies the signature using KMS.
    """
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


def verify_data_integrity(bucket: str, key: str, expected_hash: str,
                          version_id: str = None) -> bool:
    """
    Verify that the S3 object content matches the signed hash.

    This detects data tampering: if someone modified the S3 object
    after labeling, the hash won't match.
    """
    get_args = {'Bucket': bucket, 'Key': key}
    if version_id and version_id != 'LATEST':
        get_args['VersionId'] = version_id

    response = s3.get_object(**get_args)
    sha256 = hashlib.sha256()
    for chunk in iter(lambda: response['Body'].read(8192), b''):
        sha256.update(chunk)

    actual_hash = sha256.hexdigest()
    return actual_hash == expected_hash


def parse_stanag_4774_label(label_xml: str) -> dict:
    """
    Parse a STANAG 4774 XML label into a structured dict.

    Extracts PolicyIdentifier, Classification, and all Category elements
    with their types and values.
    """
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

    conf_info = root.find(f's:ConfidentialityInformation', ns)
    if conf_info is not None:
        policy_el = conf_info.find(f's:PolicyIdentifier', ns)
        if policy_el is not None:
            result['policy'] = policy_el.text or ''

        class_el = conf_info.find(f's:Classification', ns)
        if class_el is not None:
            result['classification'] = class_el.text or ''

        for category in conf_info.findall(f's:Category', ns):
            tag_name = category.get('TagName', '')
            cat_type = category.get('Type', '')
            values = [
                v.text for v in category.findall(f's:CategoryValue', ns)
                if v.text
            ]

            if tag_name == 'ReleasableTo' and cat_type == 'PERMISSIVE':
                result['releasable_to'] = values
            elif tag_name == 'SpecialAccessProgram' and cat_type == 'RESTRICTIVE':
                result['saps'].extend(values)

    orig_el = root.find(f's:Originator', ns)
    if orig_el is not None:
        result['originator'] = orig_el.text or ''

    created_el = root.find(f's:CreationDateTime', ns)
    if created_el is not None:
        result['created'] = created_el.text or ''

    return result


def get_user_attributes(username: str) -> dict:
    """Get DCS attributes from IAM user tags."""
    response = iam.list_user_tags(UserName=username)
    attrs = {}
    for tag in response['Tags']:
        if tag['Key'].startswith('dcs:'):
            attrs[tag['Key']] = tag['Value']
    return attrs


def evaluate_access(user_attrs: dict, label: dict) -> tuple[bool, list[str]]:
    """
    Evaluate whether user attributes satisfy STANAG 4774 label requirements.

    Implements the three-part check:
    1. Classification dominance (user clearance >= object classification)
    2. Releasability (PERMISSIVE - user nationality in releasable-to list)
    3. SAP access (RESTRICTIVE - user must hold all required SAPs)
    """
    reasons = []

    # 1. Classification dominance check
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

    # 2. Releasability check (PERMISSIVE category)
    user_nationality = user_attrs.get('dcs:nationality', '')
    releasable_to = label['releasable_to']

    if releasable_to and 'ALL' not in releasable_to:
        if user_nationality not in releasable_to:
            reasons.append(
                f'Nationality {user_nationality} not in releasable-to '
                f'list {releasable_to}'
            )

    # 3. SAP check (RESTRICTIVE category)
    required_saps = label['saps']
    user_saps = [
        s.strip()
        for s in user_attrs.get('dcs:saps', '').split(',')
        if s.strip()
    ]

    for sap in required_saps:
        if sap not in user_saps:
            reasons.append(
                f'Missing required SAP: {sap}. User SAPs: {user_saps}'
            )

    return len(reasons) == 0, reasons


def handler(event, context):
    """
    Lambda authorizer: verify STANAG 4778 binding, then evaluate access
    against STANAG 4774 label.
    """
    username = event.get('requestContext', {}).get('identity', {}).get('user', 'unknown')
    object_key = event.get('pathParameters', {}).get('objectKey', '')
    version_id = event.get('queryStringParameters', {}).get('versionId', 'LATEST')

    logger.info(f'Access request: user={username}, object={object_key}')

    try:
        # 1. Read label record from DynamoDB
        response = table.get_item(Key={
            'object_key': object_key,
            'object_version': version_id,
        })

        if 'Item' not in response:
            logger.warning(f'No label found for {object_key}:{version_id}')
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'authorized': False,
                    'reason': 'No STANAG 4774 label found for this object. '
                              'Unlabeled objects cannot be accessed in an '
                              'assured DCS environment.',
                })
            }

        item = response['Item']
        label_xml = item['label_xml']
        data_hash = item['data_hash']
        signature = item['binding_signature']

        # 2. STANAG 4778: Verify cryptographic binding
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
                    'reason': 'STANAG 4778 binding verification failed. '
                              'Label or data may have been tampered with. '
                              'This incident has been logged.',
                })
            }

        # 3. Verify data integrity (hash check)
        data_intact = verify_data_integrity(
            DATA_BUCKET, object_key, data_hash, version_id
        )
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
                    'reason': 'Data integrity check failed. The S3 object '
                              'has been modified since the STANAG 4774 label '
                              'was applied. Re-labeling required.',
                })
            }

        # 4. Parse STANAG 4774 label
        label = parse_stanag_4774_label(label_xml)

        # 5. Get user attributes
        user_attrs = get_user_attributes(username)

        # 6. Evaluate access policy
        authorized, reasons = evaluate_access(user_attrs, label)

        # 7. Log full decision context
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
```

## Comparison: Basic vs Assured DCS Level 1

| Aspect | Basic (S3 Tags) | Assured (STANAG 4774/4778) |
|---|---|---|
| Label format | Flat key-value S3 tags | Structured STANAG 4774 XML |
| PolicyIdentifier | None | Full NATO/national policy URN |
| Classification vocabulary | Ad-hoc strings | Formal NATO/national vocabulary |
| Category types | Implicit | Explicit PERMISSIVE/RESTRICTIVE |
| Cryptographic binding | None, labels are advisory | KMS RSA signature over label+data hash |
| Data integrity | Not checked | SHA-256 hash verified on every access |
| Label tampering detection | None | Signature verification fails |
| Data tampering detection | None | Hash mismatch detected |
| Label storage | S3 object tags (10 tags max, 256 chars each) | DynamoDB (unlimited label complexity) |
| Queryability | S3 tag-based filtering (limited) | DynamoDB GSI queries by classification, originator |
| Interoperability | Proprietary tag schema | STANAG 4774 XML extractable for any compliant system |
| Audit | CloudTrail S3 events | CloudTrail S3 + DynamoDB + KMS events |
| Cost | ~$5-15/month | ~$10-25/month |

## Testing the Architecture

### Upload a labeled object
```bash
# Upload with explicit classification metadata
aws s3 cp intel-report.pdf s3://${DATA_BUCKET}/intel-001.pdf \
  --metadata '{
    "dcs-classification": "NATO SECRET",
    "dcs-releasable-to": "GBR,USA,POL",
    "dcs-originator": "GBR",
    "dcs-policy": "NATO",
    "dcs-saps": "WALL"
  }'

# The EventBridge trigger will invoke the labeler Lambda, which:
# 1. Reads the object and computes SHA-256 hash
# 2. Builds STANAG 4774 XML label from the metadata
# 3. Signs the binding via KMS
# 4. Stores everything in DynamoDB
```

### Verify the label was created
```bash
# Read the label from DynamoDB
aws dynamodb get-item \
  --table-name ${LABEL_TABLE} \
  --key '{"object_key": {"S": "intel-001.pdf"}, "object_version": {"S": "LATEST"}}' \
  --query 'Item.label_xml.S' \
  --output text
```

### Query objects by classification
```bash
# Find all NATO SECRET objects
aws dynamodb query \
  --table-name ${LABEL_TABLE} \
  --index-name classification-index \
  --key-condition-expression 'classification = :c' \
  --expression-attribute-values '{":c": {"S": "NATO SECRET"}}'
```

### Test access as different users
```bash
# As UK SECRET user (should succeed for GBR-releasable SECRET data)
curl -H "Authorization: Bearer ${UK_SECRET_TOKEN}" \
  ${API_URL}/objects/intel-001.pdf

# As contractor (should be denied - insufficient clearance)
curl -H "Authorization: Bearer ${CONTRACTOR_TOKEN}" \
  ${API_URL}/objects/intel-001.pdf
```

### Demonstrate tamper detection
```bash
# Directly modify the S3 object (bypassing the labeling pipeline)
echo "tampered content" | aws s3 cp - s3://${DATA_BUCKET}/intel-001.pdf

# Now try to access it - the authorizer will detect the hash mismatch
# and deny access with "Data integrity check failed"
curl -H "Authorization: Bearer ${UK_SECRET_TOKEN}" \
  ${API_URL}/objects/intel-001.pdf
# Response: 403 - "The S3 object has been modified since the STANAG 4774
#                   label was applied. Re-labeling required."
```

## Production Considerations

This architecture is a demonstration. For production NATO use:

1. **PKI instead of KMS**: Use national COMSEC-issued X.509 certificates for signing, with KMS as a fallback for cloud-native operations. The `signxml` Python library supports full XMLDSig enveloped signatures with X.509 certificates.

2. **Full XMLDSig**: Replace the JSON binding approach with proper W3C XML Digital Signatures (XMLDSig) enveloped in the STANAG 4774 label, as specified by STANAG 4778.

3. **Label lifecycle**: Implement label expiry, re-labeling workflows, and label version history with full audit trails.

4. **Multi-key support**: Support multiple signing keys for different classification authorities (e.g., national vs NATO labels signed by different keys).

5. **Cross-account federation**: For coalition operations, each nation would run their own label service with their own KMS keys. The authorizer would need to verify signatures from multiple trusted keys.

6. **Guard integration**: Deploy high-assurance guards at security domain boundaries that verify STANAG 4778 bindings before allowing data to cross domains.

7. **S3 Object Lock**: Consider using S3 Object Lock (WORM) to prevent data modification after labeling, as a defense-in-depth measure alongside hash verification.
