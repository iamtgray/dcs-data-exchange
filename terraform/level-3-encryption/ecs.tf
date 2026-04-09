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

resource "aws_iam_role_policy" "ecs_execution_ssm" {
  name = "${var.project_name}-ecs-ssm-policy"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "ssm:GetParameter"]
      Resource = aws_ssm_parameter.db_password.arn
    }]
  })
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
mode: all
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
    audience: ${var.cognito_uk_client_id}
    issuer: https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_uk_pool_id}
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
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "config-init"
        }
      }
    },
    {
      name      = "opentdf"
      image     = "registry.opentdf.io/platform:v0.8.1"
      essential = true
      command   = ["start", "--config-file", "/configs/opentdf.yaml"]
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
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "opentdf"
        }
      }
    }
  ])

  volume {
    name = "config"
  }
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

  load_balancer {
    target_group_arn = aws_lb_target_group.opentdf.arn
    container_name   = "opentdf"
    container_port   = 8080
  }
}
