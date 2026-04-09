# DCS Labs Combined - Terraform

Deploys all three DCS lab levels in one go: S3 with labeled objects, Lambda data service, Cognito user pools, Verified Permissions with Cedar policies, KMS key, RDS database, and OpenTDF platform on ECS Fargate.

This is demo infrastructure - no TLS, no private subnets, no multi-AZ, passwords in variables. Fine for learning, not for production.

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

See the [full documentation](https://datacentricsecurity.org/labs/wrapup/terraform/) for details.
