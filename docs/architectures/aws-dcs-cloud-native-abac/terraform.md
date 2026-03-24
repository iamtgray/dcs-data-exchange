# Terraform: Cloud-Native DCS with AWS IAM ABAC

## Overview

This Terraform configuration deploys the cloud-native ABAC architecture. Because the authorization logic lives entirely in IAM policies (not Lambda or Verified Permissions), the infrastructure is simpler than the other DCS architectures.

## Resource summary

| Resource | Purpose | Count |
|---|---|---|
| `aws_s3_bucket` | Data bucket with ABAC bucket policy | 1 |
| `aws_s3_bucket` | CloudTrail audit bucket | 1 |
| `aws_s3_bucket_policy` | Tag-based ABAC conditions | 1 |
| `aws_iam_role` | Data reader role (federated) | 1 |
| `aws_iam_role` | Data writer role (federated) | 1 |
| `aws_iam_role` | Label admin role (break-glass) | 1 |
| `aws_iam_role` | Test user roles (UK, PL, US) | 3 |
| `aws_cognito_user_pool` | National IdP simulation | 3 |
| `aws_cognito_identity_pool` | Federation to IAM roles | 1 |
| `aws_cloudtrail` | S3 data event logging | 1 |
| `aws_organizations_policy` | SCPs for guardrails | 3 |

No Lambda functions. No DynamoDB tables. No API Gateway.

## Variables

```hcl
variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "dcs-cloud-native"
}

variable "data_bucket_name" {
  description = "Name of the S3 data bucket"
  type        = string
  default     = "dcs-data"
}

variable "audit_bucket_name" {
  description = "Name of the CloudTrail audit bucket"
  type        = string
  default     = "dcs-audit-trail"
}

variable "nations" {
  description = "Coalition nations with their classification mappings"
  type = map(object({
    clearance_level = number
    nationality     = string
    saps            = list(string)
    organisation    = string
  }))
  default = {
    uk_secret = {
      clearance_level = 2
      nationality     = "GBR"
      saps            = ["WALL"]
      organisation    = "UK-MOD"
    }
    pl_secret = {
      clearance_level = 2
      nationality     = "POL"
      saps            = []
      organisation    = "PL-MON"
    }
    us_secret = {
      clearance_level = 2
      nationality     = "USA"
      saps            = ["WALL"]
      organisation    = "US-DOD"
    }
    contractor = {
      clearance_level = 0
      nationality     = "USA"
      saps            = []
      organisation    = "CONTRACTOR"
    }
  }
}
```

## S3 data bucket

```hcl
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
            "s3:ExistingObjectTag/dcs:sap"                          = "NONE"
            "s3:ExistingObjectTag/dcs:sap/$${aws:PrincipalTag/dcs:sap}" = ""
          }
        }
      }
    ]
  })
}
```

## IAM roles

```hcl
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
```

## Cognito identity federation

```hcl
# --- National Cognito User Pools (simulating national IdPs) ---

resource "aws_cognito_user_pool" "nation" {
  for_each = {
    gbr = { name = "UK", nationality = "GBR" }
    pol = { name = "Poland", nationality = "POL" }
    usa = { name = "US", nationality = "USA" }
  }

  name = "${var.project_name}-${each.key}-users"

  schema {
    name                = "clearance"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = "0"
      max_value = "3"
    }
  }

  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints {
      min_length = "3"
      max_length = "3"
    }
  }

  schema {
    name                = "sap"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = "0"
      max_length = "256"
    }
  }

  schema {
    name                = "organisation"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = "0"
      max_length = "256"
    }
  }

  tags = {
    Project = var.project_name
    Nation  = each.value.nationality
  }
}

resource "aws_cognito_user_pool_client" "nation" {
  for_each = aws_cognito_user_pool.nation

  name         = "${each.key}-client"
  user_pool_id = each.value.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# --- Cognito Identity Pool (federates all nations into IAM roles) ---

resource "aws_cognito_identity_pool" "coalition" {
  identity_pool_name               = "${var.project_name}-coalition"
  allow_unauthenticated_identities = false

  dynamic "cognito_identity_providers" {
    for_each = aws_cognito_user_pool_client.nation
    content {
      client_id               = cognito_identity_providers.value.id
      provider_name           = aws_cognito_user_pool.nation[cognito_identity_providers.key].endpoint
      server_side_token_check = true
    }
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "coalition" {
  identity_pool_id = aws_cognito_identity_pool.coalition.id

  roles = {
    "authenticated" = aws_iam_role.data_reader.arn
  }
}
```

## CloudTrail

```hcl
resource "aws_s3_bucket" "audit" {
  bucket = var.audit_bucket_name

  tags = {
    Project = var.project_name
    Purpose = "CloudTrail audit logs"
  }
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.audit.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.audit.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "dcs" {
  name                       = "${var.project_name}-trail"
  s3_bucket_name             = aws_s3_bucket.audit.id
  include_global_service_events = true
  is_multi_region_trail      = false
  enable_log_file_validation = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.data.arn}/"]
    }
  }

  tags = {
    Project = var.project_name
    Purpose = "DCS audit trail"
  }
}
```

## Service control policies

```hcl
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
```

## Test users

```hcl
# Create test users in each national pool for scenario testing

resource "aws_cognito_user" "test_users" {
  for_each = var.nations

  user_pool_id = aws_cognito_user_pool.nation[
    each.value.nationality == "GBR" ? "gbr" :
    each.value.nationality == "POL" ? "pol" : "usa"
  ].id

  username = "test-${each.key}"

  attributes = {
    "custom:clearance"    = tostring(each.value.clearance_level)
    "custom:nationality"  = each.value.nationality
    "custom:sap"          = length(each.value.saps) > 0 ? join(",", each.value.saps) : "NONE"
    "custom:organisation" = each.value.organisation
  }
}
```

## Test data objects

```hcl
# Upload sample objects with DCS labels for scenario testing

resource "aws_s3_object" "intel_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "intel-report-001.txt"
  content      = "Sample intelligence report - SECRET GBR/USA/POL"
  content_type = "text/plain"

  tags = {
    "dcs:classification"      = "2"
    "dcs:classification-name" = "SECRET"
    "dcs:rel-GBR"             = "true"
    "dcs:rel-USA"             = "true"
    "dcs:rel-POL"             = "true"
    "dcs:sap"                 = "NONE"
    "dcs:originator"          = "POL"
    "dcs:labeled-at"          = timestamp()
  }
}

resource "aws_s3_object" "uk_eyes_only" {
  bucket       = aws_s3_bucket.data.id
  key          = "uk-eyes-only-002.txt"
  content      = "UK EYES ONLY - SECRET assessment"
  content_type = "text/plain"

  tags = {
    "dcs:classification"      = "2"
    "dcs:classification-name" = "SECRET"
    "dcs:rel-GBR"             = "true"
    "dcs:sap"                 = "NONE"
    "dcs:originator"          = "GBR"
    "dcs:labeled-at"          = timestamp()
  }
}

resource "aws_s3_object" "sap_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "wall-report-003.txt"
  content      = "SAP WALL compartmented report"
  content_type = "text/plain"

  tags = {
    "dcs:classification"      = "2"
    "dcs:classification-name" = "SECRET"
    "dcs:rel-GBR"             = "true"
    "dcs:rel-USA"             = "true"
    "dcs:sap"                 = "WALL"
    "dcs:originator"          = "GBR"
    "dcs:labeled-at"          = timestamp()
  }
}

resource "aws_s3_object" "unclass_logistics" {
  bucket       = aws_s3_bucket.data.id
  key          = "logistics-004.csv"
  content      = "Unclassified logistics data"
  content_type = "text/csv"

  tags = {
    "dcs:classification"      = "0"
    "dcs:classification-name" = "UNCLASSIFIED"
    "dcs:rel-ALL"             = "true"
    "dcs:sap"                 = "NONE"
    "dcs:originator"          = "USA"
    "dcs:labeled-at"          = timestamp()
  }
}
```

## Outputs

```hcl
output "data_bucket_name" {
  value = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  value = aws_s3_bucket.data.arn
}

output "data_reader_role_arn" {
  value = aws_iam_role.data_reader.arn
}

output "data_writer_role_arn" {
  value = aws_iam_role.data_writer.arn
}

output "label_admin_role_arn" {
  value = aws_iam_role.label_admin.arn
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.coalition.id
}

output "cognito_user_pools" {
  value = {
    for k, v in aws_cognito_user_pool.nation : k => {
      id       = v.id
      endpoint = v.endpoint
    }
  }
}

output "cloudtrail_arn" {
  value = aws_cloudtrail.dcs.arn
}
```
