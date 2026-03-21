# Terraform Reference - DCS Level 3: OpenTDF on AWS

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- Docker installed (for building/pulling OpenTDF images)
- Understanding of Levels 1 and 2 (recommended)
- Domain name with DNS access (for TLS certificates)

## Core Terraform Configuration

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

variable "domain_name" {
  description = "Base domain for services (e.g., coalition.example.com)"
  type        = string
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}
```

### vpc.tf - Network Infrastructure
```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "${var.project_name}-public-b" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "${var.project_name}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "${var.project_name}-private-b" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}
```

### kms.tf - Key Encryption Keys
```hcl
# Primary KEK for wrapping TDF Data Encryption Keys
resource "aws_kms_key" "kas_kek" {
  description             = "DCS Level 3 - KAS Key Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "KASAccess"
        Effect = "Allow"
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
    Purpose = "TDF DEK wrapping"
    DCSLevel = "3"
  }
}

resource "aws_kms_alias" "kas_kek" {
  name          = "alias/${var.project_name}-kas-kek"
  target_key_id = aws_kms_key.kas_kek.key_id
}

data "aws_caller_identity" "current" {}
```

### rds.tf - PostgreSQL for OpenTDF
```hcl
resource "aws_db_subnet_group" "opentdf" {
  name       = "${var.project_name}-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_security_group" "rds" {
  name   = "${var.project_name}-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_rds_cluster" "opentdf" {
  cluster_identifier      = "${var.project_name}-opentdf"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.4"
  database_name           = "opentdf"
  master_username         = "opentdf"
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.opentdf.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  storage_encrypted       = true
  skip_final_snapshot     = true  # Demo only - enable in production

  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }
}

resource "aws_rds_cluster_instance" "opentdf" {
  cluster_identifier = aws_rds_cluster.opentdf.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.opentdf.engine
  engine_version     = aws_rds_cluster.opentdf.engine_version
}
```

### ecs.tf - OpenTDF Platform
```hcl
resource "aws_ecs_cluster" "opentdf" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "ecs" {
  name   = "${var.project_name}-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey",
        ]
        Resource = aws_kms_key.kas_kek.arn
      }
    ]
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

  container_definitions = jsonencode([
    {
      name      = "opentdf"
      image     = "ghcr.io/opentdf/platform:latest"
      essential = true
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "OPENTDF_DB_HOST",     value = aws_rds_cluster.opentdf.endpoint },
        { name = "OPENTDF_DB_PORT",     value = "5432" },
        { name = "OPENTDF_DB_NAME",     value = "opentdf" },
        { name = "OPENTDF_DB_USER",     value = "opentdf" },
        { name = "OPENTDF_SERVER_PORT", value = "8080" },
      ]
      secrets = [
        {
          name      = "OPENTDF_DB_PASSWORD"
          valueFrom = aws_ssm_parameter.db_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.opentdf.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "opentdf"
        }
      }
    }
  ])
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
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.opentdf.arn
    container_name   = "opentdf"
    container_port   = 8080
  }
}
```

### alb.tf - Application Load Balancer
```hcl
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "opentdf" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "opentdf" {
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.opentdf.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.kas.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opentdf.arn
  }
}

resource "aws_acm_certificate" "kas" {
  domain_name       = "kas.${var.domain_name}"
  validation_method = "DNS"
}
```

### s3.tf - TDF Storage
```hcl
resource "aws_s3_bucket" "tdf_data" {
  bucket = "${var.project_name}-tdf-${data.aws_caller_identity.current.account_id}"
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

## Keycloak Configuration

Keycloak runs as a separate ECS service for identity management. Key configuration:

### Realm: coalition
```json
{
  "realm": "coalition",
  "enabled": true,
  "clients": [
    {
      "clientId": "opentdf-sdk",
      "publicClient": true,
      "redirectUris": ["*"],
      "webOrigins": ["*"],
      "directAccessGrantsEnabled": true
    },
    {
      "clientId": "opentdf-platform",
      "secret": "<generated>",
      "serviceAccountsEnabled": true
    }
  ],
  "users": [
    {
      "username": "uk-analyst-01",
      "enabled": true,
      "attributes": {
        "clearance": ["SECRET"],
        "clearanceLevel": ["2"],
        "nationality": ["GBR"],
        "saps": ["WALL"],
        "organisation": ["UK-MOD-DI"]
      }
    },
    {
      "username": "pol-analyst-01",
      "enabled": true,
      "attributes": {
        "clearance": ["NATO-SECRET"],
        "clearanceLevel": ["2"],
        "nationality": ["POL"],
        "saps": [],
        "organisation": ["PL-MON"]
      }
    },
    {
      "username": "us-analyst-01",
      "enabled": true,
      "attributes": {
        "clearance": ["IL-6"],
        "clearanceLevel": ["2"],
        "nationality": ["USA"],
        "saps": ["WALL"],
        "organisation": ["US-DOD-DIA"]
      }
    }
  ]
}
```

## OpenTDF Attribute Configuration

After deploying the platform, configure attributes via the OpenTDF API:

```bash
# Define attribute namespaces
curl -X POST https://kas.${DOMAIN}/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://coalition.example.com/attr/classification",
    "values": ["UNCLASSIFIED", "OFFICIAL", "SECRET", "TOP-SECRET"],
    "rule": "hierarchy"
  }'

curl -X POST https://kas.${DOMAIN}/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://coalition.example.com/attr/releasable",
    "values": ["GBR", "USA", "POL"],
    "rule": "anyOf"
  }'

curl -X POST https://kas.${DOMAIN}/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://coalition.example.com/attr/sap",
    "values": ["WALL"],
    "rule": "allOf"
  }'

# Assign entitlements to users
curl -X POST https://kas.${DOMAIN}/api/entitlements \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "entity": "uk-analyst-01",
    "attributes": [
      "https://coalition.example.com/attr/classification/value/SECRET",
      "https://coalition.example.com/attr/releasable/value/GBR",
      "https://coalition.example.com/attr/sap/value/WALL"
    ]
  }'
```

## Manual Setup Instructions

If building by hand instead of Terraform:

1. **Create VPC** with public and private subnets across 2 AZs
2. **Create RDS Aurora PostgreSQL** (serverless v2) in private subnets
3. **Create KMS key** for KEK with restricted key policy
4. **Create ECS Fargate cluster**
5. **Deploy Keycloak** container on ECS with realm configuration
6. **Deploy OpenTDF Platform** container on ECS, connecting to RDS and KMS
7. **Create ALB** with HTTPS listener and ACM certificate
8. **Create S3 bucket** for TDF storage
9. **Configure OpenTDF attributes** via API
10. **Test with OpenTDF SDK** from workstation

See the interactive guide (guide/index.html) for a detailed walkthrough.
