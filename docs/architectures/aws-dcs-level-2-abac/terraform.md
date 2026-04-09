# Terraform Reference - DCS Level 2: ABAC with Verified Permissions

## Overview

This Terraform configuration deploys the DCS Level 2 architecture with Amazon Verified Permissions (Cedar policies), three Cognito User Pools for coalition nations, DynamoDB data store with seed data, and a Lambda data service.

The full Terraform source code is in the repository at [`terraform/level-2-abac/`](https://github.com/iamtgray/dcs-data-exchange/tree/main/terraform/level-2-abac).

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured
- Level 1 architecture understanding (recommended to build Level 1 first)

## What gets deployed

| Resource | Purpose |
|---|---|
| `aws_cognito_user_pool` (x3) | National IdPs for UK, Poland, US |
| `aws_cognito_user` (x3) | Test analysts with DCS attributes |
| `aws_verifiedpermissions_policy_store` | Cedar policy store with ABAC schema |
| `aws_verifiedpermissions_policy` (x3) | Standard access, originator override, revoked clearance |
| `aws_dynamodb_table` | Labeled data store with seed items |
| `aws_lambda_function` | Data service with AVP authorization |

## Deploy

```bash
git clone https://github.com/iamtgray/dcs-data-exchange.git
cd dcs-data-exchange/terraform/level-2-abac
terraform init
terraform plan
terraform apply
```

## Directory structure

```
terraform/level-2-abac/
├── main.tf                  # Provider and backend config
├── variables.tf             # Input variables
├── cognito.tf               # Three national identity providers
├── verified-permissions.tf  # Cedar policy store, schema, and policies
├── dynamodb.tf              # Labeled data store with seed data
├── lambda-data-service.tf   # Lambda function and IAM role
├── outputs.tf               # Outputs
└── lambda/
    └── data-service/
        └── index.py         # Data service with AVP authorization
```

## Cedar policies

Three Cedar policies implement the DCS ABAC model:

1. **Standard access**: `permit` when `clearanceLevel >= classificationLevel AND releasableTo.contains(nationality) AND SAP check passes`
2. **Originator override**: `permit` when `nationality == originator` (data creators always have access)
3. **Revoked clearance**: `forbid` when `clearanceLevel == 0`

## Manual setup instructions

If building by hand in the AWS Console:

1. Create three Cognito User Pools (UK, Poland, US) with custom attributes
2. Create users in each pool with clearance, nationality, SAP attributes
3. Create Verified Permissions policy store with the Cedar schema
4. Add Cedar policies (standard access, originator, revoked)
5. Create DynamoDB table and seed test data items
6. Create Lambda function with the data service code
7. Create API Gateway with Cognito authorizer
8. Test by authenticating as different users and accessing different data items
