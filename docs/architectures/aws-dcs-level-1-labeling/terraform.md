# Terraform Reference - DCS Level 1: Data Labeling

## Overview

This document provides the Terraform configuration to build the DCS Level 1 architecture. You can use this as-is or as a reference for manual AWS Console setup.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- A domain name (optional, for API Gateway custom domain)

## Directory structure

```
terraform/
  main.tf              # Provider and backend config
  variables.tf         # Input variables
  s3.tf                # Data bucket and audit bucket
  lambda-authorizer.tf # Authorization Lambda
  lambda-labeler.tf    # Auto-labeling Lambda
  api-gateway.tf       # API Gateway configuration
  iam.tf               # IAM roles for simulated users
  cloudtrail.tf        # Audit logging
  outputs.tf           # Outputs (API URL, bucket name, etc.)
  lambda/
    authorizer/
      index.py         # Authorization logic
    labeler/
      index.py         # Auto-labeling logic
```

## Core Terraform configuration

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
      Project     = "dcs-level-1"
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
  default     = "eu-west-2"  # London - appropriate for UK defence context
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "dcs-level-1"
}

variable "classification_levels" {
  description = "Valid classification levels (ordered lowest to highest)"
  type        = list(string)
  default     = ["UNCLASSIFIED", "OFFICIAL", "SECRET", "TOP-SECRET"]
}

variable "valid_nationalities" {
  description = "Valid nationality codes for releasability"
  type        = list(string)
  default     = ["GBR", "USA", "POL"]
}
```

### s3.tf - Data bucket with tagging enforcement
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

# Require DCS tags on all uploaded objects
resource "aws_s3_bucket_policy" "require_tags" {
  bucket = aws_s3_bucket.data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RequireDCSTags"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          "Null" = {
            "s3:RequestObjectTag/dcs:classification" = "true"
          }
        }
      },
      {
        Sid       = "RequireReleasabilityTag"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          "Null" = {
            "s3:RequestObjectTag/dcs:releasable-to" = "true"
          }
        }
      }
    ]
  })
}

# Separate bucket for audit logs
resource "aws_s3_bucket" "audit" {
  bucket = "${var.project_name}-audit-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access on both buckets
resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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

### iam.tf - Simulated coalition users
```hcl
# UK user with SECRET clearance
resource "aws_iam_user" "uk_secret" {
  name = "${var.project_name}-user-gbr-secret"
  tags = {
    "dcs:clearance"   = "SECRET"
    "dcs:nationality"  = "GBR"
    "dcs:saps"         = "WALL"
    "dcs:organisation" = "UK-MOD"
  }
}

# Polish user with NATO SECRET clearance
resource "aws_iam_user" "pol_secret" {
  name = "${var.project_name}-user-pol-ns"
  tags = {
    "dcs:clearance"   = "NATO-SECRET"
    "dcs:nationality"  = "POL"
    "dcs:saps"         = ""
    "dcs:organisation" = "PL-MON"
  }
}

# US user with IL-6 clearance
resource "aws_iam_user" "us_il6" {
  name = "${var.project_name}-user-usa-il6"
  tags = {
    "dcs:clearance"   = "IL-6"
    "dcs:nationality"  = "USA"
    "dcs:saps"         = "WALL"
    "dcs:organisation" = "US-DOD"
  }
}

# Unclassified contractor (should be denied SECRET data)
resource "aws_iam_user" "contractor" {
  name = "${var.project_name}-user-contractor"
  tags = {
    "dcs:clearance"   = "UNCLASSIFIED"
    "dcs:nationality"  = "GBR"
    "dcs:saps"         = ""
    "dcs:organisation" = "CONTRACTOR"
  }
}

# All users get basic API Gateway invoke permissions
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
  user       = aws_iam_user.us_il6.name
  policy_arn = aws_iam_policy.api_invoke.arn
}

resource "aws_iam_user_policy_attachment" "contractor_api" {
  user       = aws_iam_user.contractor.name
  policy_arn = aws_iam_policy.api_invoke.arn
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
  timeout       = 10
  memory_size   = 256

  environment {
    variables = {
      DATA_BUCKET            = aws_s3_bucket.data.id
      CLASSIFICATION_LEVELS  = jsonencode(var.classification_levels)
    }
  }
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

# Authorizer needs to read S3 object tags and IAM user tags
resource "aws_iam_role_policy" "authorizer_policy" {
  name = "${var.project_name}-authorizer-policy"
  role = aws_iam_role.authorizer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectTagging"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:GetUser", "iam:ListUserTags"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.project_name}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
```

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
  }
}
```

## Lambda authorizer code

### lambda/authorizer/index.py
```python
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
    # Map various national classifications to a common level
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

    # Check classification level
    user_level = get_classification_level(user_attrs.get('dcs:clearance', 'UNCLASSIFIED'))
    object_level = get_classification_level(object_labels.get('dcs:classification', 'TOP-SECRET'))

    if user_level < object_level:
        reasons.append(
            f"Clearance insufficient: user has {user_attrs.get('dcs:clearance')} "
            f"(level {user_level}), object requires "
            f"{object_labels.get('dcs:classification')} (level {object_level})"
        )

    # Check nationality / releasability
    user_nationality = user_attrs.get('dcs:nationality', '')
    releasable_to = [
        n.strip() for n in object_labels.get('dcs:releasable-to', '').split(',')
    ]

    if releasable_to != ['ALL'] and user_nationality not in releasable_to:
        reasons.append(
            f"Nationality {user_nationality} not in releasable-to list {releasable_to}"
        )

    # Check SAP requirements
    required_sap = object_labels.get('dcs:sap', 'NONE')
    user_saps = [s.strip() for s in user_attrs.get('dcs:saps', '').split(',') if s.strip()]

    if required_sap != 'NONE' and required_sap not in user_saps:
        reasons.append(
            f"Missing required SAP: {required_sap}. User SAPs: {user_saps}"
        )

    return len(reasons) == 0, reasons


def handler(event, context):
    """Lambda authorizer for DCS Level 1 access control."""
    # Extract user identity and requested object
    username = event.get('requestContext', {}).get('identity', {}).get('user', 'unknown')
    object_key = event.get('pathParameters', {}).get('objectKey', '')

    logger.info(f"Access request: user={username}, object={object_key}")

    try:
        user_attrs = get_user_attributes(username)
        object_labels = get_object_labels(object_key)

        authorized, reasons = evaluate_access(user_attrs, object_labels)

        # Log the full decision context (this is the DCS audit trail)
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
```

## Lambda auto-labeler code

### lambda/labeler/index.py
```python
import json
import re
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

# Classification indicators (simplified for demonstration)
CLASSIFICATION_PATTERNS = {
    'TOP-SECRET': [
        r'\bTOP\s*SECRET\b', r'\bCOSMIC\s*TOP\s*SECRET\b', r'\bTS/SCI\b'
    ],
    'SECRET': [
        r'\bSECRET\b', r'\bNATO\s*SECRET\b', r'\bUK\s*EYES\s*ONLY\b',
        r'\bGRID\s+\d{8}\b',  # Grid references indicate at least SECRET
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

    # Check classification (highest match wins)
    for level in ['TOP-SECRET', 'SECRET', 'OFFICIAL']:
        for pattern in CLASSIFICATION_PATTERNS[level]:
            if re.search(pattern, content, re.IGNORECASE):
                classification = level
                break
        if classification != 'UNCLASSIFIED':
            break

    # Check SAP indicators
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
            # Read object content (first 10KB for analysis)
            response = s3.get_object(Bucket=bucket, Key=key, Range='bytes=0-10240')
            content = response['Body'].read().decode('utf-8', errors='ignore')

            classification, sap = analyze_content(content)

            # Apply DCS tags
            from datetime import datetime
            tags = {
                'dcs:classification': classification,
                'dcs:sap': sap,
                'dcs:labeled-by': 'auto-labeler',
                'dcs:labeled-at': datetime.utcnow().isoformat(),
            }

            # Get existing tags to preserve manually-set ones
            existing = s3.get_object_tagging(Bucket=bucket, Key=key)
            existing_tags = {t['Key']: t['Value'] for t in existing['TagSet']}

            # Only set auto-labels if not already manually labeled
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
            # Fail secure: if we can't analyze, label as highest
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
```

## Manual setup instructions

If you prefer to build this by hand in the AWS Console instead of using Terraform:

1. **Create S3 data bucket** with versioning enabled, SSE-KMS encryption
2. **Create S3 audit bucket** for CloudTrail
3. **Create IAM users** with DCS tags (clearance, nationality, saps)
4. **Create Lambda authorizer** function with the Python code above
5. **Create Lambda auto-labeler** function with S3 trigger
6. **Create API Gateway** REST API with Lambda proxy integration
7. **Enable CloudTrail** with S3 data event logging
8. **Upload test objects** to S3 with DCS tags
9. **Test access** as different IAM users

See the interactive guide (guide/index.html) for step-by-step walkthrough.
