# --- Data Reader Role (federated users assume this) ---

resource "aws_iam_role" "data_reader" {
  name = "${var.project_name}-data-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = [
          "sts:AssumeRoleWithWebIdentity",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.coalition.id
          }
          "ForAllValues:StringLike" = {
            "sts:TransitiveTagKeys" = ["dcs:*"]
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project_name
    Purpose = "DCS data reader with ABAC"
  }
}

resource "aws_iam_role_policy" "data_reader_s3" {
  name = "s3-read-abac"
  role = aws_iam_role.data_reader.id

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
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.data.arn
      }
    ]
  })
}

# --- Data Writer Role ---

resource "aws_iam_role" "data_writer" {
  name = "${var.project_name}-data-writer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = [
          "sts:AssumeRoleWithWebIdentity",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.coalition.id
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project_name
    Purpose = "DCS data writer with label enforcement"
  }
}

resource "aws_iam_role_policy" "data_writer_s3" {
  name = "s3-write-abac"
  role = aws_iam_role.data_writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectTagging"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

# --- Label Admin Role (break-glass only) ---

resource "aws_iam_role" "label_admin" {
  name = "${var.project_name}-label-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project_name
    Purpose = "DCS label admin - break-glass with MFA"
  }
}

resource "aws_iam_role_policy" "label_admin_s3" {
  name = "s3-tag-management"
  role = aws_iam_role.label_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObjectTagging",
          "s3:GetObjectTagging",
          "s3:DeleteObjectTagging"
        ]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
