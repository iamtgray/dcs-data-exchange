# DCS on AWS: how it maps

Before we start building, here's how the DCS concepts translate to AWS services. This page is your reference; come back to it as you work through the labs.

The labs use simplified AWS implementations to teach the concepts. The table below shows both the **basic** approach (what you'll build in the labs) and the **STANAG-compliant** approach (documented in the architecture references) so you can see the progression.

## Level 1: Labeling

| DCS Concept | Basic (Lab 1) | STANAG-Compliant (Architecture Ref) |
|---|---|---|
| Security labels | S3 Object Tags, flat key-value pairs like `dcs:classification=SECRET` | STANAG 4774 XML in DynamoDB, structured labels with PolicyIdentifier, typed Categories |
| Label binding | None, labels are advisory, anyone with S3 tag permissions can change them | STANAG 4778, KMS asymmetric key signs label + data hash; tampering is cryptographically detectable |
| Data integrity | S3 Versioning, tracks changes but doesn't detect tampering | SHA-256 hash, verified on every access; data modification after labeling is detected |
| Label storage | S3 tags on the object itself (10 tags max, 256 chars each) | DynamoDB, unlimited label complexity, queryable via GSIs, separate access control |
| Automated labeling | Lambda triggered on upload, analyzes content, applies tags | Lambda triggered via EventBridge, creates 4774 XML, signs via KMS, stores in DynamoDB |
| Audit trail | CloudTrail, logs S3 operations | CloudTrail, logs S3 + DynamoDB + KMS Sign/Verify operations |

## Level 2: Access Control

| DCS Concept | AWS Service | How we use it |
|---|---|---|
| User attributes (clearance, nationality) | **Amazon Cognito** | Custom user attributes in user pools |
| Policy Decision Point | **Amazon Verified Permissions** | Cedar policy language evaluates user attributes against data labels |
| Data labels | **S3 Object Tags** | Same labels from Lab 1, read by Lambda and passed to Cedar as entity attributes |
| Classification mapping | **Lambda** | Maps between national classification systems (UK SECRET = NATO SECRET = US IL-6) |
| Multiple organizations | **Separate Cognito User Pools** | One pool per nation, simulating federated identity |

## Level 3: Encryption

| DCS Concept | AWS Service | How we use it |
|---|---|---|
| Data Encryption Key (DEK) | **OpenTDF SDK** | Generates unique AES-256-GCM key per data object |
| Key Encryption Key (KEK) | **AWS KMS** | Hardware-backed key that wraps/unwraps DEKs |
| Key Access Server (KAS) | **OpenTDF on ECS Fargate** | Service that evaluates policies and releases DEKs |
| Identity Provider | **Cognito User Pools** | Issues OIDC tokens with user attributes |
| TDF file storage | **S3** | Stores encrypted TDF files (just ciphertext) |
| Attribute management | **OpenTDF Platform** | Defines attribute namespaces and user entitlements |
| Database | **RDS PostgreSQL** | Stores OpenTDF platform state |

!!! note "Level 3 is already STANAG-compliant"
    OpenTDF implements the NATO ZTDF standard directly. The TDF manifest supports STANAG 4774 labels as assertions with JWS binding (STANAG 4778). Unlike Level 1, there's no "basic vs assured" gap here; the lab builds the real thing.

## The key difference at each level

```
Level 3: Encryption        [Data encrypted + KAS policy checks]
    |                           |
    | builds on                 | uses labels from Level 1
    v                           | uses ABAC logic from Level 2
Level 2: Access Control    [Policy engine checks attributes]
    |                           |
    | builds on                 | uses labels from Level 1
    v                           |
Level 1: Labeling          [Security metadata on data]
```

And the key difference in terms of protection:

```
Level 1 (basic):    S3 admin CAN read all data    (labels are advisory)
Level 1 (assured):  S3 admin CAN read all data    (but label tampering is detectable)
Level 2:            S3 admin CAN read all data    (access control is in the app layer)
Level 3:            S3 admin CANNOT read any data  (data is encrypted, only KAS can release keys)
```

This is the fundamental progression. Each level adds more protection, and Level 3 is the only one where protection is independent of infrastructure access. Within Level 1, the "assured" variant adds cryptographic integrity guarantees that the basic variant lacks.

## Cost estimate

All three labs combined will cost approximately:

| Lab | Monthly cost | Notes |
|-----|-------------|-------|
| Lab 1 | ~$5 | S3, Lambda, CloudTrail (mostly free tier) |
| Lab 2 | ~$10-15 | Adds Cognito, Verified Permissions |
| Lab 3 | ~$15-25 | Adds ECS Fargate, RDS db.t3.micro, KMS |

!!! warning "Remember to clean up"
    The wrap-up section includes instructions to delete all resources. Lab 3 in particular runs ECS tasks and an RDS database that will accumulate costs if left running.

## Ready to start building?

Head to **[Lab 1: Data Labeling](../lab1/index.md)** to build your first DCS architecture on AWS.
