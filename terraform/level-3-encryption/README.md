# DCS Level 3: OpenTDF on AWS - Terraform

Deploys OpenTDF on ECS Fargate with KMS, RDS PostgreSQL, and Cognito.

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

Terraform creates the infrastructure, but OpenTDF still needs its attributes, subject mappings, and KAS keys configured via the API. Once the ECS task is healthy:

```bash
./provision-opentdf.sh
```

This creates the `dcs.example.com` namespace, classification/releasable/SAP attributes, Cognito-to-attribute subject mappings, and registers the KAS RSA key. You only need to run it once after the initial deploy.

## Test

```bash
./test.sh
```

Encrypts a test file and decrypts it against the running platform.

## Architecture

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-level-3-encryption/overview/) for architecture details.
