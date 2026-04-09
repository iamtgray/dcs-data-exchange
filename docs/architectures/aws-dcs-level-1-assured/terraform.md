# Terraform Reference - Assured DCS Level 1: STANAG-Compliant Labeling

## Overview

This Terraform configuration deploys the assured DCS Level 1 architecture with STANAG 4774 XML labels, STANAG 4778 cryptographic binding via KMS, DynamoDB label store, and full audit logging.

The full Terraform source code is in the repository at [`terraform/level-1-assured/`](https://github.com/iamtgray/dcs-data-exchange/tree/main/terraform/level-1-assured).

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured with credentials
- Python 3.12 runtime (for Lambda functions)
- Pre-built lxml Lambda layer zip at `lambda/layers/lxml-layer.zip`

## What gets deployed

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` (x2) | Data bucket + audit bucket |
| `aws_kms_key` | RSA-2048 asymmetric signing key for STANAG 4778 binding |
| `aws_dynamodb_table` | Label store with GSIs for classification and originator queries |
| `aws_lambda_function` (x2) | Labeler (STANAG 4774/4778 creation) + authorizer (verification) |
| `aws_api_gateway_rest_api` | REST API with `/objects/{objectKey}` endpoint |
| `aws_iam_user` (x4) | Simulated coalition users (UK, Poland, US, contractor) |
| `aws_cloudwatch_event_rule` | EventBridge trigger for auto-labeling on S3 upload |
| `aws_cloudtrail` | S3 + DynamoDB data event audit logging |

## Deploy

```bash
git clone https://github.com/iamtgray/dcs-data-exchange.git
cd dcs-data-exchange/terraform/level-1-assured
terraform init
terraform plan
terraform apply
```

!!! note "Lambda Layer"
    The lxml Lambda layer must be built separately for the Amazon Linux 2023 / Python 3.12 runtime. Place the zip at `lambda/layers/lxml-layer.zip` before running `terraform apply`.

## Directory structure

```
terraform/level-1-assured/
├── main.tf              # Provider and backend config
├── variables.tf         # Input variables
├── s3.tf                # Data bucket and audit bucket
├── dynamodb.tf          # Label store table with GSIs
├── kms.tf               # Asymmetric signing key
├── lambda-labeler.tf    # STANAG 4774/4778 label creation
├── lambda-authorizer.tf # Label verification and access control
├── api-gateway.tf       # API Gateway configuration
├── iam.tf               # IAM roles for simulated users
├── cloudtrail.tf        # Audit logging
├── eventbridge.tf       # S3 -> Lambda trigger
├── outputs.tf           # Outputs
└── lambda/
    ├── labeler/
    │   └── index.py     # STANAG 4774 label creation + 4778 binding
    └── authorizer/
        └── index.py     # Signature verification + access control
```

## Key design decisions

- Labels are structured STANAG 4774 XML stored in DynamoDB (not flat S3 tags)
- Every label is cryptographically bound to its data via KMS RSA signature (STANAG 4778)
- The authorizer verifies the binding signature and data hash before evaluating access policy
- If binding verification fails, access is denied regardless of user clearance
- If data has been modified after labeling, the hash mismatch is detected and access denied
- The labeler can `kms:Sign` but not `kms:Verify`; the authorizer can `kms:Verify` but not `kms:Sign`
- Fail-secure: objects are labeled COSMIC TOP SECRET if auto-labeling fails

## Comparison: basic vs assured DCS Level 1

| Aspect | Basic (S3 Tags) | Assured (STANAG 4774/4778) |
|---|---|---|
| Label format | Flat key-value S3 tags | Structured STANAG 4774 XML |
| Cryptographic binding | None, labels are advisory | KMS RSA signature over label+data hash |
| Data integrity | Not checked | SHA-256 hash verified on every access |
| Label tampering detection | None | Signature verification fails |
| Label storage | S3 object tags (10 tags max) | DynamoDB (unlimited label complexity) |
| Queryability | S3 tag-based filtering (limited) | DynamoDB GSI queries by classification, originator |
| Interoperability | Proprietary tag schema | STANAG 4774 XML extractable for any compliant system |
| Cost | ~$5-15/month | ~$10-25/month |

## Production considerations

This architecture is a demonstration. For production NATO use:

1. **PKI instead of KMS**: Use national COMSEC-issued X.509 certificates for signing
2. **Full XMLDSig**: Replace the JSON binding with W3C XML Digital Signatures enveloped in the STANAG 4774 label
3. **Label lifecycle**: Implement label expiry, re-labeling workflows, and version history
4. **Multi-key support**: Support multiple signing keys for different classification authorities
5. **Cross-account federation**: Each nation runs their own label service with their own KMS keys
6. **Guard integration**: Deploy high-assurance guards at security domain boundaries
7. **S3 Object Lock**: Consider WORM to prevent data modification after labeling
