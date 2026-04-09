# Terraform Reference - DCS Level 1: Data Labeling

## Overview

This Terraform configuration deploys the DCS Level 1 architecture with S3 tag-based security labels, a Lambda authorizer, auto-labeling Lambda, API Gateway, and CloudTrail audit logging.

The full Terraform source code is in the repository at [`terraform/level-1-labeling/`](https://github.com/iamtgray/dcs-data-exchange/tree/main/terraform/level-1-labeling).

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials

## What gets deployed

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` (x2) | Data bucket with tag enforcement + audit bucket |
| `aws_lambda_function` (x2) | Authorizer (access control) + auto-labeler (content analysis) |
| `aws_api_gateway_rest_api` | REST API with `/objects/{objectKey}` endpoint |
| `aws_iam_user` (x4) | Simulated coalition users (UK, Poland, US, contractor) |
| `aws_cloudtrail` | S3 data event audit logging |

## Deploy

```bash
git clone https://github.com/iamtgray/dcs-data-exchange.git
cd dcs-data-exchange/terraform/level-1-labeling
terraform init
terraform plan
terraform apply
```

## Directory structure

```
terraform/level-1-labeling/
├── main.tf              # Provider and backend config
├── variables.tf         # Input variables
├── s3.tf                # Data bucket and audit bucket
├── lambda-authorizer.tf # Authorization Lambda
├── api-gateway.tf       # API Gateway configuration
├── iam.tf               # IAM roles for simulated users
├── cloudtrail.tf        # Audit logging
├── outputs.tf           # Outputs (API URL, bucket name, etc.)
└── lambda/
    ├── authorizer/
    │   └── index.py     # Authorization logic
    └── labeler/
        └── index.py     # Auto-labeling logic
```

## Key design decisions

- S3 object tags serve as security labels (`dcs:classification`, `dcs:releasable-to`, `dcs:sap`)
- A bucket policy denies uploads without required DCS tags
- The Lambda authorizer reads IAM user tags (user attributes) and S3 object tags (data labels) to make access decisions
- The auto-labeler analyses content using regex patterns and applies labels automatically, failing secure to TOP-SECRET if analysis fails
- CloudTrail logs all S3 data events for audit

## Manual setup instructions

If you prefer to build this by hand in the AWS Console instead of using Terraform:

1. Create S3 data bucket with versioning enabled, SSE-KMS encryption
2. Create S3 audit bucket for CloudTrail
3. Create IAM users with DCS tags (clearance, nationality, saps)
4. Create Lambda authorizer function with the Python code from the repo
5. Create Lambda auto-labeler function with S3 trigger
6. Create API Gateway REST API with Lambda proxy integration
7. Enable CloudTrail with S3 data event logging
8. Upload test objects to S3 with DCS tags
9. Test access as different IAM users
