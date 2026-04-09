# DCS Level 3: OpenTDF on AWS - Terraform

Deploys the DCS Level 3 architecture with OpenTDF platform on ECS Fargate, KMS key encryption keys, RDS PostgreSQL, and Cognito integration.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- Cognito User Pool ID from Level 2 deployment

## Deploy

```bash
terraform init
terraform plan -var="db_password=YOUR_SECURE_PASSWORD" -var="cognito_uk_pool_id=YOUR_POOL_ID"
terraform apply -var="db_password=YOUR_SECURE_PASSWORD" -var="cognito_uk_pool_id=YOUR_POOL_ID"
```

## Architecture

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-level-3-encryption/overview/) for architecture details.
