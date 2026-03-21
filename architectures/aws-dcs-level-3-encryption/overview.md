# Architecture: DCS Level 3 - Cryptographic Protection with OpenTDF on AWS

## Purpose

This architecture implements **DCS Level 3 (Protection via Encryption)**, the most mature DCS level. It deploys the OpenTDF platform on AWS to provide cryptographic data protection where security travels with the data itself, regardless of where it's stored or transmitted.

After building it, you'll understand:
- How TDF wraps data with encryption and embedded access policies
- How a Key Access Server (KAS) enforces policies at decryption time
- How federated key management works across multiple organizations
- How DCS Level 3 provides protection even when infrastructure is compromised
- The complete DCS stack: labeling + access control + encryption

## Architecture Overview

```
+------------------------------------------------------------------+
|                 "Coalition Shared" AWS Account                    |
|                                                                   |
|   +-----------------------------------------------------------+  |
|   |                    Application Load Balancer               |  |
|   |  kas.coalition.example.com                                 |  |
|   +----------------------------+------------------------------+  |
|                                |                                  |
|   +----------------------------v------------------------------+  |
|   |              ECS Fargate Cluster                           |  |
|   |                                                            |  |
|   |  +------------------+  +------------------+                |  |
|   |  | OpenTDF Platform |  | OpenTDF Platform |  (auto-scale) |  |
|   |  | Container        |  | Container        |               |  |
|   |  |                  |  |                  |                |  |
|   |  | - KAS Service    |  | - KAS Service    |               |  |
|   |  | - Policy Engine  |  | - Policy Engine  |               |  |
|   |  | - Attribute Svc  |  | - Attribute Svc  |               |  |
|   |  +--------+---------+  +--------+---------+               |  |
|   |           |                      |                         |  |
|   +-----------|----------------------|-------------------------+  |
|               |                      |                            |
|        +------v------+        +------v------+                     |
|        | RDS          |        | AWS KMS     |                    |
|        | PostgreSQL   |        |             |                    |
|        |              |        | KEK (Key    |                    |
|        | - Attributes |        |  Encryption |                    |
|        | - Policies   |        |  Key)       |                    |
|        | - Entitlements|       |             |                    |
|        | - Audit logs |        | Wraps/      |                    |
|        +--------------+        | Unwraps DEKs|                    |
|                                +-------------+                    |
|                                                                   |
|   +-----------------------------------------------------------+  |
|   |              Keycloak (Identity Provider)                  |  |
|   |              on ECS Fargate                                |  |
|   |                                                            |  |
|   |  - Authenticates users from all nations                   |  |
|   |  - Issues OIDC tokens with user attributes                |  |
|   |  - Federated to national IdPs (SAML/OIDC)                |  |
|   |  - Attributes: clearance, nationality, SAPs, org          |  |
|   +-----------------------------------------------------------+  |
|                                                                   |
|   +-----------------------------------------------------------+  |
|   |              S3 Data Bucket                                |  |
|   |                                                            |  |
|   |  All data stored as .tdf files                            |  |
|   |  Data is encrypted - S3 only stores ciphertext            |  |
|   |  Even S3 admin cannot read payload without KAS auth       |  |
|   +-----------------------------------------------------------+  |
+------------------------------------------------------------------+

        |                    |                    |
        v                    v                    v
+------------------+ +------------------+ +------------------+
| UK User          | | Polish User      | | US User          |
| Workstation      | | Workstation      | | Workstation      |
|                  | |                  | |                  |
| OpenTDF SDK      | | OpenTDF SDK      | | OpenTDF SDK      |
| (JavaScript)     | | (JavaScript)     | | (JavaScript)     |
|                  | |                  | |                  |
| Encrypts data    | | Encrypts data    | | Encrypts data    |
| locally as TDF   | | locally as TDF   | | locally as TDF   |
| Decrypts TDF     | | Decrypts TDF     | | Decrypts TDF     |
| after KAS auth   | | after KAS auth   | | after KAS auth   |
+------------------+ +------------------+ +------------------+
```

## How It Demonstrates DCS Level 3

| DCS Concept | AWS Implementation |
|---|---|
| **Data encryption** | AES-256-GCM via OpenTDF SDK (client-side encryption) |
| **Key management** | AWS KMS wraps/unwraps DEKs; OpenTDF KAS manages key access |
| **Policy enforcement at decryption** | KAS evaluates ABAC policies before releasing DEK |
| **Labels bound to encrypted data** | TDF manifest contains labels, policies, and key references |
| **Federated key management** | Multiple KAS instances possible (one per nation account) |
| **Audit trail** | KAS logs every key access request; CloudTrail logs KMS operations |
| **Protection independent of infrastructure** | Even S3 admin or AWS root account cannot read TDF payloads |

## The critical difference: why Level 3 matters

In Level 1 and Level 2, anyone with infrastructure access (DynamoDB admin, S3 admin, AWS root) can read all data. Labels and policies are only enforced by the application.

In Level 3:
- Data is encrypted at the client before it ever reaches AWS
- Only the KAS can release the DEK needed to decrypt
- The KAS evaluates ABAC policies before releasing any key
- Even AWS itself cannot read the data, only users who pass KAS policy checks
- If you copy the TDF file to a USB drive, it remains encrypted and policy-protected
- If the S3 bucket is breached, attackers get only ciphertext

This is true data-centric security: protection travels with the data, independent of infrastructure.

## Components

### 1. OpenTDF Platform on ECS Fargate

The OpenTDF platform runs as a containerized service providing:

**Key Access Service (KAS)**:
- Receives DEK unwrap requests from client SDKs
- Authenticates the requesting user via OIDC token
- Evaluates ABAC policy from the TDF manifest
- If authorized: unwraps DEK using AWS KMS and returns to client
- If denied: returns 403 with policy violation details
- Logs every request (authorized and denied)

**Attribute Service**:
- Manages the attribute namespace (clearance levels, nationalities, SAPs)
- Defines attribute hierarchy (SECRET > OFFICIAL > UNCLASSIFIED)
- Maps user identity attributes to entitlements

**Policy Engine**:
- Evaluates ABAC policies embedded in TDF manifests
- Supports complex boolean logic (AND, OR, NOT)
- Supports attribute hierarchy comparisons

**Container image**: `ghcr.io/opentdf/platform:latest`

**Configuration** (environment variables):
```
OPENTDF_DB_HOST=<rds-endpoint>
OPENTDF_DB_PORT=5432
OPENTDF_DB_NAME=opentdf
OPENTDF_KAS_OIDC_ISSUER=https://keycloak.coalition.example.com/realms/coalition
OPENTDF_KAS_KMS_KEY_ID=<aws-kms-key-id>
```

### 2. AWS KMS (Key Encryption Keys)

KMS provides the root key hierarchy:

```
AWS KMS Key (KEK - never leaves KMS)
    |
    +-- Wraps DEK for TDF object #1
    +-- Wraps DEK for TDF object #2
    +-- Wraps DEK for TDF object #3
    ...
```

**Key policy** restricts usage to the OpenTDF ECS task role:
```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::role/opentdf-kas-role" },
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "*"
    }
  ]
}
```

- **Why KMS**: Hardware-backed, FIPS 140-3 Level 3 validated, audit-logged via CloudTrail. The KEK never leaves the HSM. This mirrors the security properties of dedicated HSMs in defence environments.

### 3. Keycloak Identity Provider

Handles authentication and attribute assertion for all coalition users.

**Realm**: `coalition`

**Identity Federation**:
- UK users: Federated via SAML to UK IdP (simulated with local users for demo)
- Polish users: Federated via SAML to Polish IdP
- US users: Federated via SAML to US IdP

**Token attributes** (included in OIDC ID token):
```json
{
  "sub": "user-uk-analyst-01",
  "clearance": "SECRET",
  "clearanceLevel": 2,
  "nationality": "GBR",
  "saps": ["WALL"],
  "organisation": "UK-MOD-DI",
  "iss": "https://keycloak.coalition.example.com/realms/coalition"
}
```

### 4. RDS PostgreSQL

Stores OpenTDF platform state:
- **Attribute definitions**: The namespace of attributes (clearance, nationality, etc.)
- **Entitlements**: Mapping of user identities to attribute values
- **Key access audit**: Log of every KAS request and decision
- **Policy templates**: Reusable policy patterns

### 5. S3 Data Bucket

Stores TDF files. Unlike Level 1 and Level 2, the S3 bucket contains only ciphertext. No special S3 policies needed for access control because the data is self-protecting.

**Bucket policy** is simple: allow authenticated users to read/write. All real access control happens at the KAS level when users try to decrypt.

### 6. OpenTDF Client SDK

Installed on user workstations. Available in JavaScript, Java, and Go.

**Encryption flow**:
```javascript
import { TDF3Client } from '@opentdf/client';

const client = new TDF3Client({
  kasEndpoint: 'https://kas.coalition.example.com',
  oidcOrigin: 'https://keycloak.coalition.example.com',
  clientId: 'opentdf-sdk',
});

// Encrypt data with ABAC policy
const tdfStream = await client.encrypt({
  source: fileBuffer,
  metadata: {
    labels: {
      classification: 'SECRET',
      releasableTo: ['GBR', 'USA', 'POL'],
      sap: 'NONE',
      originator: 'POL'
    }
  },
  scope: {
    attributes: [
      'https://coalition.example.com/attr/classification/value/SECRET',
      'https://coalition.example.com/attr/releasable/value/GBR',
      'https://coalition.example.com/attr/releasable/value/USA',
      'https://coalition.example.com/attr/releasable/value/POL'
    ]
  }
});

// Upload TDF to S3
await s3.putObject({ Bucket: 'dcs-data', Key: 'intel-001.tdf', Body: tdfStream });
```

**Decryption flow**:
```javascript
// Download TDF from S3
const tdfData = await s3.getObject({ Bucket: 'dcs-data', Key: 'intel-001.tdf' });

// Decrypt - SDK contacts KAS, KAS evaluates policy, returns DEK if authorized
const plaintext = await client.decrypt({
  source: tdfData.Body
});
// If user lacks required attributes, this throws PolicyDeniedError
```

## TDF File Structure

```
intel-001.tdf (ZIP archive)
|
|-- 0.payload                    # AES-256-GCM encrypted data
|-- 0.manifest.json              # Metadata and key access info
```

**manifest.json contents**:
```json
{
  "encryptionInformation": {
    "type": "split",
    "keyAccess": [
      {
        "type": "wrapped",
        "url": "https://kas.coalition.example.com",
        "protocol": "kas",
        "wrappedKey": "<base64-encoded-wrapped-DEK>",
        "policyBinding": {
          "alg": "HS256",
          "hash": "<HMAC-of-policy>"
        }
      }
    ],
    "method": {
      "algorithm": "AES-256-GCM",
      "isStreamable": true
    }
  },
  "payload": {
    "type": "reference",
    "url": "0.payload",
    "protocol": "zip",
    "mimeType": "application/pdf",
    "integrityInformation": {
      "rootSignature": {
        "alg": "HS256",
        "sig": "<payload-integrity-hash>"
      }
    }
  },
  "assertions": [
    {
      "id": "classification",
      "type": "handling",
      "scope": "payload",
      "statement": {
        "format": "json",
        "value": "{\"classification\":\"SECRET\",\"releasableTo\":[\"GBR\",\"USA\",\"POL\"]}"
      },
      "binding": {
        "method": "jws",
        "signature": "<JWS-signature-binding-assertion-to-manifest>"
      }
    }
  ]
}
```

Security properties of this structure:
1. `wrappedKey` can only be unwrapped by the KAS specified in `url`
2. `policyBinding` prevents the policy from being tampered with after encryption
3. `assertions` carry STANAG 4774-style labels, bound via JWS (STANAG 4778)
4. `rootSignature` on payload detects any data tampering
5. Even with the TDF file, you cannot decrypt without KAS authorization

## Federated Architecture (Advanced)

For true coalition operations, each nation runs its own KAS:

```
+------------------+     +------------------+     +------------------+
| UK Account       |     | Poland Account   |     | US Account       |
|                  |     |                  |     |                  |
| UK-KAS           |     | PL-KAS           |     | US-KAS           |
| (OpenTDF +       |     | (OpenTDF +       |     | (OpenTDF +       |
|  UK KMS key)     |     |  PL KMS key)     |     |  US KMS key)     |
|                  |     |                  |     |                  |
| UK IdP           |     | PL IdP           |     | US IdP           |
| UK policies      |     | PL policies      |     | US policies      |
| UK audit logs    |     | PL audit logs    |     | US audit logs    |
+------------------+     +------------------+     +------------------+

TDF manifest with AnyOf key access:
{
  "keyAccess": [
    { "url": "https://kas.uk.mod.example.com",  "wrappedKey": "<UK-KEK-wrapped>" },
    { "url": "https://kas.pl.mon.example.com",  "wrappedKey": "<PL-KEK-wrapped>" },
    { "url": "https://kas.us.dod.example.com",  "wrappedKey": "<US-KEK-wrapped>" }
  ]
}

Any nation's KAS can independently authorize and unwrap.
Each nation maintains sovereignty over their keys and policies.
```

## Scenarios to Demonstrate

### Scenario A: Basic Encrypt-Decrypt
1. Polish analyst encrypts sensor report as TDF
2. Uploads to shared S3 bucket
3. UK analyst downloads TDF file
4. SDK contacts KAS, KAS checks UK analyst's attributes
5. KAS authorizes, returns DEK
6. SDK decrypts locally

### Scenario B: Access Denied at KAS
1. Contractor downloads TDF file from S3 (anyone can download ciphertext)
2. SDK contacts KAS with contractor's OIDC token
3. KAS evaluates: contractor clearance UNCLASSIFIED < required SECRET
4. KAS returns PolicyDeniedError
5. Data remains encrypted on contractor's machine

### Scenario C: Data Exfiltration Protection
1. Insider copies TDF files to external USB drive
2. TDF files contain only ciphertext
3. Without KAS authorization, files are useless
4. Even if insider has the TDF SDK, KAS won't authorize without valid credentials

### Scenario D: Policy Update After Sharing
1. Polish analyst encrypts report, shares with GBR and USA
2. Later, policy admin revokes USA access in KAS
3. US analyst who previously could decrypt now gets denied
4. Data doesn't change - policy changed at KAS
5. This is "policy persistence" - control after sharing

### Scenario E: Federated KAS (Advanced)
1. Polish analyst encrypts with both PL-KAS and UK-KAS key access
2. UK analyst contacts UK-KAS (never touches Polish infrastructure)
3. UK-KAS unwraps with UK KMS key, evaluates UK policies
4. UK analyst decrypts - Polish KAS never involved
5. Each nation maintains sovereignty over their citizens' access

## What you'll learn

After building and using this architecture, you'll understand:

1. Data is truly self-protecting. Unlike Levels 1 and 2, encrypted data cannot be read by infrastructure administrators, cloud providers, or attackers who breach the storage layer.

2. Key management is the control plane. Whoever controls the KAS controls access to data. This is why federated KAS matters: each nation controls their own.

3. Policy enforcement happens at consumption time. Policies are evaluated when someone tries to decrypt, not when data is stored. This allows dynamic access control after sharing.

4. TDF is an envelope. The TDF wraps data with everything needed for access control: the encrypted payload, the wrapped key, the policy, and the labels. It's a complete data-centric security package.

5. The full DCS stack works together. Level 3 builds on Level 1 (labels in assertions) and Level 2 (ABAC policies) and adds encryption. All three levels are present in a single TDF file.

## Terraform Overview

See `terraform/` for complete IaC. Key resources:
- `aws_ecs_cluster` + `aws_ecs_service` for OpenTDF platform
- `aws_ecs_service` for Keycloak
- `aws_rds_cluster` for PostgreSQL
- `aws_kms_key` for KEK
- `aws_lb` + `aws_lb_target_group` for ALB
- `aws_s3_bucket` for TDF storage
- `aws_ecr_repository` for container images (or pull from GHCR)
- VPC, subnets, security groups for network isolation

## Estimated Cost

Approximately $50-100/month for demonstration:
- ECS Fargate: ~$30-50 (2 tasks, 0.5 vCPU, 1GB each)
- RDS PostgreSQL: ~$15-30 (db.t3.micro)
- KMS: ~$1/month per key + $0.03/10,000 requests
- ALB: ~$15/month
- S3: minimal for demo data volumes
