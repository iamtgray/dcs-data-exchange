# ---------------------------------------------------------------------------
# KAS key pairs (RSA + EC) for OpenTDF platform
# ---------------------------------------------------------------------------
resource "tls_private_key" "kas_rsa" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "kas_rsa" {
  private_key_pem = tls_private_key.kas_rsa.private_key_pem
  subject {
    common_name = "kas-rsa"
  }
  validity_period_hours = 8760
  allowed_uses          = ["digital_signature", "key_encipherment"]
}

resource "tls_private_key" "kas_ec" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "kas_ec" {
  private_key_pem = tls_private_key.kas_ec.private_key_pem
  subject {
    common_name = "kas-ec"
  }
  validity_period_hours = 8760
  allowed_uses          = ["digital_signature"]
}

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
# Elastic IP + NLB for stable platform addressing
# ---------------------------------------------------------------------------
resource "aws_eip" "opentdf" {
  domain = "vpc"
  tags   = { Name = "dcs-level3-opentdf" }
}

resource "aws_lb" "opentdf" {
  name               = "dcs-level3-nlb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = data.aws_subnets.default.ids[0]
    allocation_id = aws_eip.opentdf.id
  }
}

resource "aws_lb_target_group" "opentdf" {
  name        = "dcs-level3-tg"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    protocol = "HTTP"
    path     = "/healthz"
    port     = "8080"
  }
}

resource "aws_lb_listener" "opentdf" {
  load_balancer_arn = aws_lb.opentdf.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opentdf.arn
  }
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

  container_definitions = jsonencode([
    {
      name      = "config-init"
      image     = "public.ecr.aws/docker/library/alpine:3.20"
      essential = false
      command = [
        "sh", "-c",
        <<-CMD
        mkdir -p /configs /configs/keys &&
        cat > /configs/keys/kas-private.pem <<'RSAKEY'
${tls_private_key.kas_rsa.private_key_pem}RSAKEY
        cat > /configs/keys/kas-cert.pem <<'RSACERT'
${tls_self_signed_cert.kas_rsa.cert_pem}RSACERT
        cat > /configs/keys/kas-ec-private.pem <<'ECKEY'
${tls_private_key.kas_ec.private_key_pem}ECKEY
        cat > /configs/keys/kas-ec-cert.pem <<'ECCERT'
${tls_self_signed_cert.kas_ec.cert_pem}ECCERT
        chmod -R 755 /configs &&
        cat > /configs/opentdf.yaml <<'EOF'
logger:
  level: info
  type: text
  output: stdout
db:
  host: ${aws_db_instance.opentdf.address}
  port: 5432
  database: opentdf
  user: opentdf
  password: ${var.db_password}
  sslmode: require
  runMigration: true
mode: all,-entityresolution
services:
  entityresolution:
    mode: claims
  kas:
    keyring:
      - kid: r1
        alg: rsa:2048
        legacy: true
      - kid: e1
        alg: ec:secp256r1
        legacy: true
    preview:
      key_management: true
    root_key: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
server:
  port: 8080
  public_hostname: ${aws_eip.opentdf.public_ip}
  auth:
    enabled: true
    enforceDPoP: false
    audience: ${aws_cognito_user_pool_client.nation["uk"].id}
    issuer: https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.nation["uk"].id}
    policy:
      client_id_claim: sub
      csv: |
        p, role:admin, *, *, allow
        p, role:standard, *, *, allow
        p, role:unknown, *, *, allow
  cryptoProvider:
    standard:
      keys:
        - kid: r1
          alg: rsa:2048
          private: /configs/keys/kas-private.pem
          cert: /configs/keys/kas-cert.pem
        - kid: e1
          alg: ec:secp256r1
          private: /configs/keys/kas-ec-private.pem
          cert: /configs/keys/kas-ec-cert.pem
EOF
        CMD
      ]
      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/configs"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.opentdf.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "config-init"
        }
      }
    },
    {
      name         = "opentdf"
      image        = "registry.opentdf.io/platform:v0.8.1"
      essential    = true
      command      = ["start", "--config-file", "/configs/opentdf.yaml"]
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      dependsOn = [{
        containerName = "config-init"
        condition     = "SUCCESS"
      }]
      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/configs"
      }]
      environment = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.opentdf.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "opentdf"
        }
      }
    }
  ])

  volume {
    name = "config"
  }
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

  load_balancer {
    target_group_arn = aws_lb_target_group.opentdf.arn
    container_name   = "opentdf"
    container_port   = 8080
  }
}
