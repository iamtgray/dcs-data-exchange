# Terraform Reference - DCS Level 3: OpenTDF on AWS

## Overview

This Terraform configuration deploys the DCS Level 3 architecture with OpenTDF platform on ECS Fargate, KMS key encryption keys, RDS PostgreSQL, and Cognito integration.

The full Terraform source code is in the repository at [`terraform/level-3-encryption/`](https://github.com/iamtgray/dcs-data-exchange/tree/main/terraform/level-3-encryption).

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- Understanding of Levels 1 and 2 (recommended)
- Cognito User Pool ID from Level 2 deployment

## Design: simplified infrastructure

This Terraform uses the default VPC, a single Fargate task with a public IP, and a db.t3.micro RDS instance. No custom VPC, no ALB, no NAT gateway. The focus is on the DCS components (KMS, OpenTDF, Cognito), not networking.

## What gets deployed

| Resource | Purpose |
|---|---|
| `aws_kms_key` | Key Encryption Key for TDF DEK wrapping |
| `aws_db_instance` | PostgreSQL for OpenTDF platform state |
| `aws_ecs_cluster` + `aws_ecs_service` | Fargate cluster running OpenTDF |
| `aws_ecs_task_definition` | OpenTDF container with KMS and Cognito config |
| `aws_s3_bucket` | TDF data storage |
| `aws_security_group` (x2) | RDS and ECS security groups |
| `aws_cloudwatch_log_group` | Container logs |

## Deploy

```bash
git clone https://github.com/iamtgray/dcs-data-exchange.git
cd dcs-data-exchange/terraform/level-3-encryption
terraform init
terraform plan -var="db_password=YOUR_SECURE_PASSWORD" -var="cognito_uk_pool_id=YOUR_POOL_ID"
terraform apply -var="db_password=YOUR_SECURE_PASSWORD" -var="cognito_uk_pool_id=YOUR_POOL_ID"
```

## Directory structure

```
terraform/level-3-encryption/
├── main.tf        # Provider config
├── variables.tf   # Input variables (db_password, cognito_uk_pool_id)
├── data.tf        # Default VPC and subnets
├── kms.tf         # Key encryption keys
├── rds.tf         # PostgreSQL for OpenTDF
├── ecs.tf         # OpenTDF platform on Fargate
├── s3.tf          # TDF storage bucket
├── outputs.tf     # Outputs
└── README.md
```

## Post-deployment configuration

After deploying the platform, configure attributes and subject mappings via the OpenTDF API:

```bash
KAS_IP="YOUR-TASK-PUBLIC-IP"

# Define attribute namespaces
curl -X POST http://$KAS_IP:8080/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://dcs.example.com/attr/classification",
    "values": ["UNCLASSIFIED", "OFFICIAL", "SECRET", "TOP-SECRET"],
    "rule": "hierarchy"
  }'

curl -X POST http://$KAS_IP:8080/api/attributes/namespaces \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "name": "https://dcs.example.com/attr/releasable",
    "values": ["GBR", "USA", "POL"],
    "rule": "anyOf"
  }'
```

## Manual setup instructions

If building by hand instead of Terraform:

1. Create KMS key with alias `dcs-level3-kas-kek`
2. Create RDS PostgreSQL (db.t3.micro) in default VPC
3. Create ECS Fargate cluster `dcs-level3`
4. Create IAM roles for task execution and KMS access
5. Run ECS task with public IP in default VPC public subnet
6. Configure OpenTDF attributes and subject mappings via API
7. Test with OpenTDF CLI from workstation
