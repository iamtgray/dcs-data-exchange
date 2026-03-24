# Terraform Reference - DCS Level 3: OpenTDF on AWS

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- Understanding of Levels 1 and 2 (recommended)

## Design: simplified infrastructure

This Terraform uses the default VPC, a single Fargate task with a public IP, and a db.t3.micro RDS instance. No custom VPC, no ALB, no NAT gateway. The focus is on the DCS components (KMS, OpenTDF, Cognito), not networking.

## Core Terraform configuration

### variables.tf
```hcl
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "dcs-level-3"
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "cognito_uk_pool_id" {
  description = "Cognito User Pool ID for the UK IdP (from Lab 2)"
  type        = string
}
```

### data.tf - Default VPC and subnets
```hcl
data "aws_caller_identity" "current" {}

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

### kms.tf - Key encryption keys
```hcl
resource "aws_kms_key" "kas_kek" {
  description             = "DCS Level 3 - KAS Key Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

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
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose  = "TDF DEK wrapping"
    DCSLevel = "3"
  }
}

resource "aws_kms_alias" "kas_kek" {
  name          = "alias/${var.project_name}-kas-kek"
  target_key_id = aws_kms_key.kas_kek.key_id
}
```

### rds.tf - PostgreSQL for OpenTDF
```hcl
resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
    description = "PostgreSQL from default VPC"
  }
}

resource "aws_db_instance" "opentdf" {
  identifier     = "${var.project_name}-opentdf"
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
  skip_final_snapshot    = true  # Demo only

  tags = {
    Name     = "${var.project_name}-opentdf"
    DCSLevel = "3"
  }
}
```

### ecs.tf - OpenTDF platform
```hcl
resource "aws_ecs_cluster" "opentdf" {
  name = "${var.project_name}-cluster"
}

resource "aws_security_group" "ecs" {
  name   = "${var.project_name}-ecs-sg"
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
  name = "${var.project_name}-ecs-task-role"
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
  name = "${var.project_name}-ecs-kms-policy"
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
  name = "${var.project_name}-ecs-execution-role"
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
  name              = "/ecs/${var.project_name}/opentdf"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "opentdf" {
  family                   = "${var.project_name}-opentdf"
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
      { name = "OPENTDF_DB_HOST",                            value = aws_db_instance.opentdf.address },
      { name = "OPENTDF_DB_PORT",                            value = "5432" },
      { name = "OPENTDF_DB_NAME",                            value = "opentdf" },
      { name = "OPENTDF_DB_USER",                            value = "opentdf" },
      { name = "OPENTDF_SERVER_PORT",                        value = "8080" },
      { name = "OPENTDF_SERVER_AUTH_ISSUER",                 value = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_uk_pool_id}" },
      { name = "OPENTDF_SERVER_AUTH_AUDIENCE",               value = "http://localhost:8080" },
      { name = "OPENTDF_SERVICES_ENTITYRESOLUTION_MODE",     value = "claims" },
    ]
    secrets = [{
      name      = "OPENTDF_DB_PASSWORD"
      valueFrom = aws_ssm_parameter.db_password.arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.opentdf.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "opentdf"
      }
    }
  }])
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db-password"
  type  = "SecureString"
  value = var.db_password
}

resource "aws_ecs_service" "opentdf" {
  name            = "${var.project_name}-opentdf"
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

### s3.tf - TDF storage
```hcl
resource "aws_s3_bucket" "tdf_data" {
  bucket = "dcs-lab-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "tdf_data" {
  bucket = aws_s3_bucket.tdf_data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "tdf_data" {
  bucket                  = aws_s3_bucket.tdf_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Cognito configuration (from Lab 2)

This architecture reuses the Cognito user pools created in Lab 2. The OpenTDF platform is configured in Claims ERS mode, reading user attributes directly from Cognito's OIDC tokens.

### Required Cognito resources (already created in Lab 2)

| Resource | Name | Purpose |
|----------|------|---------|
| UK User Pool | `dcs-level2-uk-idp` | UK users with custom attributes |
| PL User Pool | `dcs-level2-pol-idp` | Polish users with custom attributes |
| US User Pool | `dcs-level2-us-idp` | US users with custom attributes |

### Custom attributes in each pool

| Attribute | Example (UK) | Token claim |
|-----------|-------------|-------------|
| `clearance` | SECRET | `custom:clearance` |
| `clearanceLevel` | 2 | `custom:clearanceLevel` |
| `nationality` | GBR | `custom:nationality` |
| `saps` | WALL | `custom:saps` |

## OpenTDF attribute and subject mapping configuration

After deploying the platform, configure attributes and subject mappings via the OpenTDF API:

```bash
KAS_IP="YOUR-TASK-PUBLIC-IP"

# Define attribute namespaces
curl -X POST http://$KAS_IP:8080/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://dcs.example.com/attr/classification",
    "values": ["UNCLASSIFIED", "OFFICIAL", "SECRET", "TOP-SECRET"],
    "rule": "hierarchy"
  }'

curl -X POST http://$KAS_IP:8080/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://dcs.example.com/attr/releasable",
    "values": ["GBR", "USA", "POL"],
    "rule": "anyOf"
  }'

curl -X POST http://$KAS_IP:8080/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://dcs.example.com/attr/sap",
    "values": ["WALL"],
    "rule": "allOf"
  }'

# Create subject mappings (connect Cognito claims to attributes)
curl -X POST http://$KAS_IP:8080/api/subject-mappings \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "attribute_value_id": "<RELEASABLE_GBR_ID>",
    "subject_condition_set": {
      "subject_sets": [{
        "condition_groups": [{
          "boolean_operator": "AND",
          "conditions": [{
            "subject_external_selector_value": ".custom:nationality",
            "operator": "IN",
            "subject_external_values": ["GBR"]
          }]
        }]
      }]
    }
  }'
```

## Manual setup instructions

If building by hand instead of Terraform:

1. **Create KMS key** with alias `dcs-level3-kas-kek`
2. **Create RDS PostgreSQL** (db.t3.micro) in default VPC
3. **Create ECS Fargate cluster** `dcs-level3`
4. **Create IAM roles** for task execution and KMS access
5. **Run ECS task** with public IP in default VPC public subnet
6. **Configure OpenTDF attributes and subject mappings** via API
7. **Test with OpenTDF CLI** from workstation

See the interactive guide for a detailed walkthrough.
