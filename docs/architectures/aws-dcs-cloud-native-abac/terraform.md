# Terraform: Cloud-Native DCS with AWS IAM ABAC

## Overview

This Terraform configuration deploys the cloud-native ABAC architecture. Because the authorization logic lives entirely in IAM policies (not Lambda or Verified Permissions), the infrastructure is simpler than the other DCS architectures.

The full Terraform source code is in the repository at [`terraform/cloud-native-abac/`](https://github.com/iamtgray/dcs-data-exchange/tree/main/terraform/cloud-native-abac).

No Lambda functions. No DynamoDB tables. No API Gateway.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- AWS Organizations (for SCPs - optional)

## What gets deployed

| Resource | Purpose | Count |
|---|---|---|
| `aws_s3_bucket` | Data bucket with ABAC bucket policy | 1 |
| `aws_s3_bucket` | CloudTrail audit bucket | 1 |
| `aws_s3_bucket_policy` | Tag-based ABAC conditions | 1 |
| `aws_iam_role` | Data reader, writer, label admin roles | 3 |
| `aws_cognito_user_pool` | National IdP simulation | 3 |
| `aws_cognito_identity_pool` | Federation to IAM roles | 1 |
| `aws_cloudtrail` | S3 data event logging | 1 |
| `aws_organizations_policy` | SCPs for guardrails (optional) | 3 |

## Deploy

```bash
git clone https://github.com/iamtgray/dcs-data-exchange.git
cd dcs-data-exchange/terraform/cloud-native-abac
terraform init
terraform plan
terraform apply
```

## Directory structure

```
terraform/cloud-native-abac/
├── main.tf          # Provider config
├── variables.tf     # Input variables (nations, bucket names)
├── s3.tf            # Data bucket with ABAC bucket policy
├── iam.tf           # Data reader, writer, label admin roles
├── cognito.tf       # National user pools + identity pool federation
├── cloudtrail.tf    # Audit trail with S3 data events
├── scp.tf           # Service control policies (requires AWS Organizations)
├── test-users.tf    # Cognito test users per nation
├── test-data.tf     # Sample S3 objects with DCS labels
├── outputs.tf       # Outputs
└── README.md
```

## Key design decisions

- Authorization lives entirely in S3 bucket policy conditions using `s3:ExistingObjectTag` and `aws:PrincipalTag`
- Cognito Identity Pool federates national user pools into IAM roles with session tags
- Label admin role requires MFA (break-glass only)
- SCPs prevent tag tampering and untagged uploads at the organization level
- No custom code needed for access control decisions
