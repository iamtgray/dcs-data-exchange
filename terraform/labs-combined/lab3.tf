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
# ECS -- Cluster, Roles, Task Definition, Service
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
    image     = "registry.opentdf.io/platform:nightly"
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
