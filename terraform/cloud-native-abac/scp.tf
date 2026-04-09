# Note: These require AWS Organizations and must be applied from the
# management account. Include them only if deploying in an org context.

resource "aws_organizations_policy" "deny_unlabeled_uploads" {
  name        = "${var.project_name}-deny-unlabeled-uploads"
  description = "Deny S3 PutObject to DCS bucket without classification tags"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnlabeledS3Uploads"
        Effect   = "Deny"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.data_bucket_name}/*"
        Condition = {
          Null = {
            "s3:RequestObjectTag/dcs:classification" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy" "deny_label_tampering" {
  name        = "${var.project_name}-deny-label-tampering"
  description = "Deny tag modification on DCS bucket except by label admin"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyLabelDeletion"
        Effect = "Deny"
        Action = [
          "s3:DeleteObjectTagging",
          "s3:PutObjectTagging"
        ]
        Resource = "arn:aws:s3:::${var.data_bucket_name}/*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:role/${var.project_name}-label-admin"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy" "deny_federation_without_tags" {
  name        = "${var.project_name}-deny-untagged-federation"
  description = "Deny STS federation to DCS roles without clearance session tag"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyFederationWithoutTags"
        Effect = "Deny"
        Action = [
          "sts:AssumeRoleWithSAML",
          "sts:AssumeRoleWithWebIdentity"
        ]
        Resource = "arn:aws:iam::*:role/${var.project_name}-data-*"
        Condition = {
          Null = {
            "aws:RequestTag/dcs:clearance" = "true"
          }
        }
      }
    ]
  })
}
