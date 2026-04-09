# DCS Cloud-Native ABAC - Terraform

Deploys the cloud-native DCS architecture using IAM-native ABAC with S3 bucket policies. No Lambda, no DynamoDB, no API Gateway - authorization lives entirely in IAM policies.

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- AWS Organizations (for SCPs - optional)

## Deploy

```bash
terraform init
terraform plan
terraform apply
```

## Architecture

See the [full documentation](https://datacentricsecurity.org/architectures/aws-dcs-cloud-native-abac/overview/) for architecture details.
