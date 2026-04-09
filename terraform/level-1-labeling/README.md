# DCS Level 1: Data Labeling - Terraform

Deploys the DCS Level 1 architecture with S3 tag-based security labels, a Lambda authorizer, auto-labeling Lambda, API Gateway, and CloudTrail audit logging.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Architecture

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-level-1-labeling/overview/) for architecture details.
