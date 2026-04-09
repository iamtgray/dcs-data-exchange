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
