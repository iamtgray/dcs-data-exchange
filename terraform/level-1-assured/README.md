# DCS Level 1 Assured: STANAG-Compliant Labeling - Terraform

Deploys the assured DCS Level 1 architecture with STANAG 4774 XML labels, STANAG 4778 cryptographic binding via KMS, DynamoDB label store, and full audit logging.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- Python 3.12 runtime (for Lambda functions)
- Pre-built lxml Lambda layer zip at `lambda/layers/lxml-layer.zip`

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Note on Lambda Layer

The lxml Lambda layer must be built separately for the Amazon Linux 2023 / Python 3.12 runtime. Place the zip at `lambda/layers/lxml-layer.zip` before running `terraform apply`.

## Architecture

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-level-1-assured/overview/) for architecture details.
