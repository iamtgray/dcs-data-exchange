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
