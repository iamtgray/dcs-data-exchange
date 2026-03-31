# Reference architectures

Technical architectures implementing Data-Centric Security on AWS. Each includes a high-level overview with component diagrams and a Terraform deployment guide.

The architectures progress through the three DCS levels, with multiple implementation options depending on your requirements.

| Architecture | DCS Level | Key Services | Approach |
|---|---|---|---|
| [Level 1 - Data Labeling](aws-dcs-level-1-labeling/overview.md) | Level 1 | S3, Lambda, API Gateway | S3 tags as security labels with Lambda authorizer |
| [Level 1 - Assured Labeling](aws-dcs-level-1-assured/overview.md) | Level 1 | S3, KMS, DynamoDB, Lambda | STANAG 4774/4778 compliant with cryptographic binding |
| [Level 2 - ABAC](aws-dcs-level-2-abac/overview.md) | Level 2 | Verified Permissions, Cognito, DynamoDB | Cedar policies with attribute-based access control |
| [Level 2 - Cloud-Native ABAC](aws-dcs-cloud-native-abac/overview.md) | Level 1+2 | IAM, S3, STS | IAM-native ABAC with no custom authorization code |
| [Level 3 - Encryption](aws-dcs-level-3-encryption/overview.md) | Level 3 | ECS Fargate, KMS, RDS, Cognito | OpenTDF platform with federated key management |

### Cross-cutting guides

| Guide | Description |
|---|---|
| [Deployment Guide](dcs-levels-deployment-guide.md) | Sequential deployment and testing across all three DCS levels |
| [Threat Model](dcs-levels-threat-model.md) | Per-level threat analysis with mitigations and residual risk |

!!! tip "Labs vs Reference Architectures"
    The [hands-on labs](../labs/lab1/index.md) teach DCS concepts step-by-step using simplified implementations. These reference architectures show production-grade designs with full STANAG compliance, Terraform automation, and security analysis.
