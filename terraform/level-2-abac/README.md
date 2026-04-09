# DCS Level 2: ABAC with Verified Permissions - Terraform

Deploys the DCS Level 2 architecture with Amazon Verified Permissions (Cedar policies), three Cognito User Pools for coalition nations, DynamoDB data store with seed data, and a Lambda data service.

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

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-level-2-abac/overview/) for architecture details.
