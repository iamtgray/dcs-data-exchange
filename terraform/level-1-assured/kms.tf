resource "aws_kms_key" "label_signing" {
  description              = "DCS Level 1 - STANAG 4778 label binding signing key"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "RSA_2048"
  deletion_window_in_days  = 30
  enable_key_rotation      = false

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
