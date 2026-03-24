# Automate Everything with Terraform

You've built all three DCS levels by hand. Now here's the Terraform to deploy the entire thing in one go.

This creates every resource from Labs 1, 2, and 3: the S3 bucket with labeled objects, the Lambda data service, Cognito user pools with test users, Verified Permissions with Cedar policies, the KMS key, the RDS database, and the OpenTDF platform on ECS Fargate.

!!! warning "This is demo infrastructure"
    No TLS, no private subnets, no multi-AZ, passwords in variables. Fine for learning. Not for production.

## Project structure

```
dcs-terraform/
├── main.tf           # Provider and data sources
├── variables.tf      # Input variables
├── outputs.tf        # Useful outputs (URLs, IDs)
├── lab1.tf           # S3 bucket, objects, labels, Lambda
├── lab2.tf           # Cognito, Verified Permissions, updated Lambda
├── lab3.tf           # KMS, RDS, ECS, OpenTDF platform
├── lambda/
│   └── lab2.py       # Lambda function code (Lab 2 version)
└── terraform.tfvars  # Your values
```

## main.tf

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
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}
```

## variables.tf

```hcl
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "db_password" {
  description = "Password for the OpenTDF RDS database"
  type        = string
  sensitive   = true
}

variable "user_password" {
  description = "Password for all Cognito test users"
  type        = string
  default     = "TempPass1!"
  sensitive   = true
}
```

## terraform.tfvars

```hcl
aws_region  = "eu-west-2"
db_password = "CHANGE-ME-to-something-secure"
```

## lab1.tf — S3 Bucket, Data Objects, Labels, Lambda

```hcl
# ---------------------------------------------------------------------------
# S3 Data Bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "data" {
  bucket = "dcs-lab-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
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

# ---------------------------------------------------------------------------
# Test Data Objects with DCS Labels (S3 tags)
# ---------------------------------------------------------------------------
resource "aws_s3_object" "logistics_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "logistics-report.txt"
  content      = <<-EOT
    LOGISTICS SUMMARY - Q1 2025
    Supply levels normal across all forward operating bases.
    No classified information in this report.
  EOT
  content_type = "text/plain"
  tags = {
    "dcs:classification" = "UNCLASSIFIED"
    "dcs:releasable-to"  = "ALL"
    "dcs:sap"            = "NONE"
    "dcs:originator"     = "USA"
  }
}

resource "aws_s3_object" "intel_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "intel-report.txt"
  content      = <<-EOT
    INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
    Enemy forces observed moving through GRID 12345678.
    Estimated 200 personnel with armoured vehicles.
    Movement pattern suggests preparation for offensive operations.
    Recommend increased surveillance.
  EOT
  content_type = "text/plain"
  tags = {
    "dcs:classification" = "SECRET"
    "dcs:releasable-to"  = "GBR,USA,POL"
    "dcs:sap"            = "NONE"
    "dcs:originator"     = "POL"
  }
}

resource "aws_s3_object" "operation_wall" {
  bucket       = aws_s3_bucket.data.id
  key          = "operation-wall.txt"
  content      = <<-EOT
    OPERATION WALL - PHASE 2 UPDATE
    UK HUMINT sources report enemy command structure reorganisation.
    Source reliability: A2. Information confirmed by SIGINT.
    Coalition response options being developed.
  EOT
  content_type = "text/plain"
  tags = {
    "dcs:classification" = "SECRET"
    "dcs:releasable-to"  = "GBR,USA,POL"
    "dcs:sap"            = "WALL"
    "dcs:originator"     = "GBR"
  }
}
```

```hcl
# ---------------------------------------------------------------------------
# Lambda Execution Role (starts with Lab 1 permissions, Lab 2 adds AVP)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "dcs-lab-data-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "dcs-lab-data-service-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectTagging"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "verifiedpermissions:IsAuthorized"
        Resource = "*"
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

The Lambda function code is in `lambda/lab2.py` (shown below). We deploy the Lab 2 version directly since it's a superset of Lab 1 — it returns data with labels when allowed, and a 403 when denied.

```hcl
# ---------------------------------------------------------------------------
# Lambda Function (Lab 2 version with Verified Permissions)
# ---------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/lab2.py"
  output_path = "${path.module}/lambda/lab2.zip"
}

resource "aws_lambda_function" "data_service" {
  function_name    = "dcs-lab-data-service"
  role             = aws_iam_role.lambda.arn
  handler          = "lab2.lambda_handler"
  runtime          = "python3.12"
  timeout          = 15
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      DATA_BUCKET     = aws_s3_bucket.data.id
      POLICY_STORE_ID = aws_verifiedpermissions_policy_store.dcs.id
    }
  }
}

resource "aws_lambda_function_url" "data_service" {
  function_name      = aws_lambda_function.data_service.function_name
  authorization_type = "NONE"
}
```

## lambda/lab2.py

Save this as `lambda/lab2.py` in your Terraform project directory:

```python
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
    releasable_to = [r.strip() for r in releasable_raw.split(',') if r.strip()]
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
```

## lab2.tf — Cognito, Verified Permissions, Cedar Policies

```hcl
# ---------------------------------------------------------------------------
# Cognito User Pools (one per nation)
# ---------------------------------------------------------------------------
locals {
  nations = {
    uk = {
      pool_name   = "dcs-level2-uk-idp"
      client_name = "dcs-uk-client"
      user        = "uk-analyst-01"
      clearance   = "SECRET"
      nationality = "GBR"
      saps        = "WALL"
      level       = "2"
    }
    pol = {
      pool_name   = "dcs-level2-pol-idp"
      client_name = "dcs-pol-client"
      user        = "pol-analyst-01"
      clearance   = "NATO-SECRET"
      nationality = "POL"
      saps        = ""
      level       = "2"
    }
    us = {
      pool_name   = "dcs-level2-us-idp"
      client_name = "dcs-us-client"
      user        = "us-analyst-01"
      clearance   = "IL-6"
      nationality = "USA"
      saps        = "WALL"
      level       = "2"
    }
  }
}

resource "aws_cognito_user_pool" "nation" {
  for_each = local.nations
  name     = each.value.pool_name

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  schema {
    name                = "clearance"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 1; max_length = 50 }
  }
  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints { min_length = 2; max_length = 5 }
  }
  schema {
    name                = "saps"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 0; max_length = 200 }
  }
  schema {
    name                = "clearanceLevel"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints { min_value = "0"; max_value = "5" }
  }
}

resource "aws_cognito_user_pool_client" "nation" {
  for_each     = local.nations
  name         = each.value.client_name
  user_pool_id = aws_cognito_user_pool.nation[each.key].id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  generate_secret = false
}

resource "aws_cognito_user" "analyst" {
  for_each     = local.nations
  user_pool_id = aws_cognito_user_pool.nation[each.key].id
  username     = each.value.user
  password     = var.user_password

  attributes = {
    "custom:clearance"      = each.value.clearance
    "custom:nationality"    = each.value.nationality
    "custom:saps"           = each.value.saps
    "custom:clearanceLevel" = each.value.level
  }
}
```

```hcl
# ---------------------------------------------------------------------------
# Verified Permissions — Policy Store, Schema, Cedar Policies
# ---------------------------------------------------------------------------
resource "aws_verifiedpermissions_policy_store" "dcs" {
  description = "DCS Level 2 - Coalition ABAC policies"
  validation_settings {
    mode = "STRICT"
  }
}

resource "aws_verifiedpermissions_schema" "dcs" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    value = jsonencode({
      DCS = {
        entityTypes = {
          User = {
            shape = {
              type = "Record"
              attributes = {
                clearanceLevel = { type = "Long", required = true }
                nationality    = { type = "String", required = true }
                saps           = { type = "Set", element = { type = "String" } }
              }
            }
          }
          DataObject = {
            shape = {
              type = "Record"
              attributes = {
                classificationLevel = { type = "Long", required = true }
                releasableTo        = { type = "Set", element = { type = "String" } }
                requiredSap         = { type = "String", required = true }
                originator          = { type = "String", required = true }
              }
            }
          }
        }
        actions = {
          read = {
            appliesTo = {
              principalTypes = ["User"]
              resourceTypes  = ["DataObject"]
            }
          }
          write = {
            appliesTo = {
              principalTypes = ["User"]
              resourceTypes  = ["DataObject"]
            }
          }
        }
      }
    })
  }
}

# Policy 1: Standard access — clearance + nationality + SAP
resource "aws_verifiedpermissions_policy" "standard_access" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Standard access - clearance, nationality, and SAP check"
      statement   = <<-CEDAR
        permit(
          principal is DCS::User,
          action == DCS::Action::"read",
          resource is DCS::DataObject
        ) when {
          principal.clearanceLevel >= resource.classificationLevel &&
          resource.releasableTo.contains(principal.nationality) &&
          (resource.requiredSap == "" || principal.saps.contains(resource.requiredSap))
        };
      CEDAR
    }
  }
}

# Policy 2: Originator access — data creators always have access
resource "aws_verifiedpermissions_policy" "originator_access" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Originator access - data creators always have access"
      statement   = <<-CEDAR
        permit(
          principal is DCS::User,
          action == DCS::Action::"read",
          resource is DCS::DataObject
        ) when {
          principal.nationality == resource.originator
        };
      CEDAR
    }
  }
}

# Policy 3: Block revoked clearances
resource "aws_verifiedpermissions_policy" "block_revoked" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Block users with revoked clearance (level 0)"
      statement   = <<-CEDAR
        forbid(
          principal is DCS::User,
          action,
          resource is DCS::DataObject
        ) when {
          principal.clearanceLevel == 0
        };
      CEDAR
    }
  }
}
```

## lab3.tf — KMS, RDS, ECS, OpenTDF Platform

```hcl
# ---------------------------------------------------------------------------
# KMS Key (Key Encryption Key for TDF DEKs)
# ---------------------------------------------------------------------------
resource "aws_kms_key" "kas_kek" {
  description             = "Key Encryption Key for DCS Level 3 KAS - wraps TDF Data Encryption Keys"
  deletion_window_in_days = 7
  enable_key_rotation     = true

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
        Sid       = "KASAccess"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.ecs_task.arn }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "kas_kek" {
  name          = "alias/dcs-level3-kas-kek"
  target_key_id = aws_kms_key.kas_kek.key_id
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL (db.t3.micro, default VPC)
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name   = "dcs-level3-rds-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "PostgreSQL from default VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "opentdf" {
  identifier     = "dcs-level3-opentdf"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "opentdf"
  username = "opentdf"
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "dcs-level3-opentdf" }
}

# ---------------------------------------------------------------------------
# ECS — Cluster, Roles, Task Definition, Service
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "opentdf" {
  name = "dcs-level3"
}

resource "aws_security_group" "ecs" {
  name   = "dcs-level3-ecs-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenTDF platform API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_task" {
  name = "dcs-level3-kas-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_kms" {
  name = "dcs-level3-kms-policy"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = aws_kms_key.kas_kek.arn
    }]
  })
}

resource "aws_iam_role" "ecs_execution" {
  name = "dcs-level3-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "opentdf" {
  name              = "/ecs/dcs-level3/opentdf"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "opentdf" {
  family                   = "dcs-level3-opentdf"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "opentdf"
    image     = "ghcr.io/opentdf/platform:latest"
    essential = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "OPENTDF_DB_HOST",                        value = aws_db_instance.opentdf.address },
      { name = "OPENTDF_DB_PORT",                        value = "5432" },
      { name = "OPENTDF_DB_DATABASE",                    value = "opentdf" },
      { name = "OPENTDF_DB_USER",                        value = "opentdf" },
      { name = "OPENTDF_DB_PASSWORD",                    value = var.db_password },
      { name = "OPENTDF_SERVER_PORT",                    value = "8080" },
      { name = "OPENTDF_SERVER_AUTH_ISSUER",             value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.nation["uk"].id}" },
      { name = "OPENTDF_SERVER_AUTH_AUDIENCE",           value = "http://localhost:8080" },
      { name = "OPENTDF_SERVICES_ENTITYRESOLUTION_MODE", value = "claims" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.opentdf.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "opentdf"
      }
    }
  }])
}

resource "aws_ecs_service" "opentdf" {
  name            = "opentdf"
  cluster         = aws_ecs_cluster.opentdf.id
  task_definition = aws_ecs_task_definition.opentdf.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}
```

## outputs.tf

```hcl
output "data_bucket" {
  value = aws_s3_bucket.data.id
}

output "lambda_function_url" {
  value = aws_lambda_function_url.data_service.function_url
}

output "policy_store_id" {
  value = aws_verifiedpermissions_policy_store.dcs.id
}

output "cognito_uk_pool_id" {
  value = aws_cognito_user_pool.nation["uk"].id
}

output "cognito_uk_client_id" {
  value = aws_cognito_user_pool_client.nation["uk"].id
}

output "cognito_pol_pool_id" {
  value = aws_cognito_user_pool.nation["pol"].id
}

output "cognito_pol_client_id" {
  value = aws_cognito_user_pool_client.nation["pol"].id
}

output "cognito_us_pool_id" {
  value = aws_cognito_user_pool.nation["us"].id
}

output "cognito_us_client_id" {
  value = aws_cognito_user_pool_client.nation["us"].id
}

output "kms_key_id" {
  value = aws_kms_key.kas_kek.key_id
}

output "rds_endpoint" {
  value = aws_db_instance.opentdf.address
}

output "ecs_cluster" {
  value = aws_ecs_cluster.opentdf.name
}

output "cognito_issuer_url" {
  value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.nation["uk"].id}"
}
```

## Deploy

```bash
cd dcs-terraform
terraform init
terraform plan
terraform apply
```

After apply completes, Terraform prints the outputs. The ECS task takes a couple of minutes to start — find its public IP in the ECS console under the running task's Configuration section.

## Test it

### Lab 1 test (data + labels, no access control)

The Lambda deploys with the Lab 2 code, so you need to pass user attributes. To replicate the Lab 1 experience (everything returned), just pass a valid user:

```bash
FUNCTION_URL=$(terraform output -raw lambda_function_url)

curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "intel-report.txt",
    "username": "uk-analyst-01",
    "clearanceLevel": 2,
    "nationality": "GBR",
    "saps": ["WALL"]
  }' | python3 -m json.tool
```

### Lab 2 test (ABAC denial)

```bash
curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{
    "objectKey": "operation-wall.txt",
    "username": "pol-analyst-01",
    "clearanceLevel": 2,
    "nationality": "POL",
    "saps": []
  }' | python3 -m json.tool
```

Expected: 403 — Polish analyst doesn't have the WALL SAP.

### Lab 3 test (encrypt/decrypt)

Once the ECS task is running, find its public IP and configure the OpenTDF CLI:

```bash
KAS_IP="YOUR-TASK-PUBLIC-IP"
export OPENTDF_ENDPOINT="http://$KAS_IP:8080"
export OIDC_ENDPOINT="$(terraform output -raw cognito_issuer_url)"
export OIDC_CLIENT_ID="$(terraform output -raw cognito_uk_client_id)"
```

Then follow the Lab 3 steps from Step 3 onwards (configure attributes, encrypt, decrypt). The OpenTDF attribute and subject mapping configuration still needs to be done via the API — Terraform creates the infrastructure, but the OpenTDF platform's internal configuration (attribute namespaces and subject mappings) is done through its own REST API after it boots.

## Tear down

```bash
terraform destroy
```

This deletes everything across all three labs in one command. The KMS key enters a 7-day deletion waiting period (AWS minimum).
