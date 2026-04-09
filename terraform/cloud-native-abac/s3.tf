resource "aws_s3_bucket" "data" {
  bucket = var.data_bucket_name

  tags = {
    Project = var.project_name
    Purpose = "DCS labeled data store"
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "dcs_abac" {
  bucket = aws_s3_bucket.data.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DCSReadAccess"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.data_reader.arn }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          NumericLessThanEquals = {
            "s3:ExistingObjectTag/dcs:classification" = "$${aws:PrincipalTag/dcs:clearance}"
          }
          StringEquals = {
            "s3:ExistingObjectTag/dcs:rel-$${aws:PrincipalTag/dcs:nationality}" = "true"
          }
        }
      },
      {
        Sid       = "DCSOriginatorOverride"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.data_reader.arn }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          StringEquals = {
            "s3:ExistingObjectTag/dcs:originator" = "$${aws:PrincipalTag/dcs:nationality}"
          }
        }
      },
      {
        Sid       = "DCSWriteRequireLabels"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.data_writer.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          StringLike = {
            "s3:RequestObjectTag/dcs:classification" = "*"
          }
          NumericLessThanEquals = {
            "s3:RequestObjectTag/dcs:classification" = "$${aws:PrincipalTag/dcs:clearance}"
          }
        }
      },
      {
        Sid       = "DenyUntaggedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          Null = {
            "s3:RequestObjectTag/dcs:classification" = "true"
          }
        }
      },
      {
        Sid    = "DenyTagTampering"
        Effect = "Deny"
        Principal = "*"
        Action = [
          "s3:DeleteObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          ArnNotEquals = {
            "aws:PrincipalArn" = aws_iam_role.label_admin.arn
          }
        }
      },
      {
        Sid       = "DenySAPMismatch"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.data.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:ExistingObjectTag/dcs:sap"                                         = "NONE"
            "s3:ExistingObjectTag/dcs:sap/$${aws:PrincipalTag/dcs:sap}" = ""
          }
        }
      }
    ]
  })
}
