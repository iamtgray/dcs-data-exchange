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

## Post-deploy: provision OpenTDF

Terraform creates the infrastructure but the OpenTDF platform needs its attribute definitions, subject mappings, and KAS keys configured via its API. Once the ECS task is healthy:

```bash
./provision-opentdf.sh
```

This creates the `dcs.example.com` namespace, classification/releasable/SAP attributes, Cognito-to-attribute subject mappings, and registers the KAS RSA key. You only need to run it once after the initial deploy.

## Test

```bash
./test.sh
```

Runs an end-to-end encrypt/decrypt cycle against the deployed platform.

## Architecture

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-level-3-encryption/overview/) for architecture details.
