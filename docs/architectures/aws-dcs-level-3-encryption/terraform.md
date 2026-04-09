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

This Terraform uses the default VPC, a single Fargate task, and a db.t3.micro RDS instance. No custom VPC, no NAT gateway. The focus is on the DCS components (KMS, OpenTDF, Cognito), not networking.

!!! note "Difference from the lab"
    The lab has you run a Fargate task with a public IP and manually note the ephemeral address. The Terraform improves on this by adding a Network Load Balancer with an Elastic IP. This gives the platform a stable address that's known at plan time, survives task restarts, and can be baked into the OpenTDF `server.public_hostname` config automatically. The NLB also means the KAS URL embedded in TDF manifests at encryption time won't break if the underlying task cycles.

## What gets deployed

| Resource | Purpose |
|---|---|
| `aws_kms_key` | Key Encryption Key for TDF DEK wrapping |
| `aws_db_instance` | PostgreSQL for OpenTDF platform state |
| `aws_ecs_cluster` + `aws_ecs_service` | Fargate cluster running OpenTDF |
| `aws_ecs_task_definition` | OpenTDF container with config init sidecar, KAS keys, and Cognito config |
| `aws_eip` + `aws_lb` (NLB) | Stable public IP for the platform (see note above) |
| `aws_s3_bucket` | TDF data storage |
| `aws_security_group` (x2) | RDS and ECS security groups |
| `aws_cloudwatch_log_group` | Container logs |
| `tls_private_key` + `tls_self_signed_cert` | KAS RSA and EC key pairs for TDF key wrapping |

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
├── main.tf                # Provider config
├── variables.tf           # Input variables (db_password, cognito IDs)
├── data.tf                # Default VPC and subnets
├── kms.tf                 # Key encryption keys
├── kas-keys.tf            # TLS key pairs for KAS (RSA + EC)
├── rds.tf                 # PostgreSQL for OpenTDF
├── ecs.tf                 # OpenTDF platform on Fargate (with config init sidecar)
├── eip.tf                 # Elastic IP + NLB for stable addressing
├── s3.tf                  # TDF storage bucket
├── outputs.tf             # Outputs (platform_ip, platform_url, etc.)
├── provision-opentdf.sh   # Post-deploy: create attributes + subject mappings
├── test.sh                # End-to-end encrypt/decrypt test
└── README.md
```

## Post-deployment configuration

After `terraform apply`, the platform IP is available as a Terraform output:

```bash
terraform output platform_url
# http://X.X.X.X:8080
```

Then run the provisioning script to configure attributes and subject mappings:

```bash
./provision-opentdf.sh
```

This creates the DCS attribute namespace (`dcs.example.com`), classification/releasable/SAP attributes, subject mappings from Cognito JWT claims, and registers the KAS keys.

## Manual setup instructions

If building by hand instead of Terraform:

1. Create KMS key with alias `dcs-level3-kas-kek`
2. Create RDS PostgreSQL (db.t3.micro) in default VPC
3. Create ECS Fargate cluster `dcs-level3`
4. Create IAM roles for task execution and KMS access
5. Run ECS task with public IP in default VPC public subnet
6. Configure OpenTDF attributes and subject mappings via API
7. Test with OpenTDF CLI from workstation
