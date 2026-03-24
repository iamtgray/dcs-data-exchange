# Architecture: DCS Level 3 - Cryptographic Protection with OpenTDF on AWS

## Purpose

This architecture implements **DCS Level 3 (Protection via Encryption)**, the most mature DCS level. It deploys the OpenTDF platform on AWS to provide cryptographic data protection where security travels with the data itself, regardless of where it's stored or transmitted.

After building it, you'll understand:
- How TDF wraps data with encryption and embedded access policies
- How a Key Access Server (KAS) enforces policies at decryption time
- How AWS-native identity (Cognito) provides user attributes for access decisions
- How federated key management works across multiple organizations
- How DCS Level 3 provides protection even when infrastructure is compromised
- The complete DCS stack: labeling + access control + encryption

## Architecture Overview

```
+------------------------------------------------------------------+
|                 "Coalition Shared" AWS Account                    |
|                         Default VPC                               |
|                                                                   |
|   +-----------------------------------------------------------+  |
|   |              ECS Fargate Task (Public IP)                  |  |
|   |                                                            |  |
|   |  +------------------------------------------------------+ |  |
|   |  | OpenTDF Platform Container                            | |  |
|   |  |                                                       | |  |
|   |  | - KAS Service (Key Access Server)                     | |  |
|   |  | - Attribute Service                                   | |  |
|   |  | - Claims ERS (Entity Resolution)                      | |  |
|   |  | - Port 8080 (public)                                  | |  |
|   |  +-------------------------+-----------------------------+ |  |
|   |                            |                               |  |
|   +----------------------------|-------------------------------+  |
|                                |                                  |
|        +-----------------------+------------------------+         |
|        |                                                |         |
|  +-----v------+                                  +------v------+  |
|  | RDS          |                                | AWS KMS     |  |
|  | PostgreSQL   |                                |             |  |
|  | db.t3.micro  |                                | KEK (Key    |  |
|  |              |                                |  Encryption |  |
|  | - Attributes |                                |  Key)       |  |
|  | - Subject    |                                |             |  |
|  |   mappings   |                                | Wraps/      |  |
|  | - Audit logs |                                | Unwraps DEKs|  |
|  +--------------+                                +-------------+  |
|                                                                   |
|   +-----------------------------------------------------------+  |
|   |              Cognito User Pools (from Lab 2)               |  |
|   |                                                            |  |
|   |  UK Pool          PL Pool          US Pool                |  |
|   |  - uk-analyst-01  - pol-analyst-01 - us-analyst-01        |  |
|   |  - clearance      - clearance      - clearance            |  |
|   |  - nationality    - nationality    - nationality          |  |
|   |  - saps           - saps           - saps                 |  |
|   |                                                            |  |
|   |  Issues OIDC tokens with custom attributes as claims      |  |
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
| OpenTDF CLI      | | OpenTDF CLI      | | OpenTDF CLI      |
|                  | |                  | |                  |
| Encrypts data    | | Encrypts data    | | Encrypts data    |
| locally as TDF   | | locally as TDF   | | locally as TDF   |
| Decrypts TDF     | | Decrypts TDF     | | Decrypts TDF     |
| after KAS auth   | | after KAS auth   | | after KAS auth   |
+------------------+ +------------------+ +------------------+
```

## Design philosophy: minimal infrastructure

This architecture deliberately uses the simplest possible AWS setup so you can focus on the DCS concepts rather than networking:

- **Default VPC** — no custom VPC, no NAT gateway, no private subnets
- **ECS Fargate with public IP** — the task runs in a default public subnet with `assignPublicIp: ENABLED`
- **No load balancer** — the KAS is accessed directly via the task's public IP on port 8080
- **db.t3.micro RDS** — free-tier eligible, single-AZ, in the default VPC
- **Cognito from Lab 2** — no new identity infrastructure

In production you'd add a load balancer, private subnets, TLS, and multi-AZ. But for learning DCS, none of that matters. What matters is the encryption, the KAS policy checks, and the key hierarchy.

## How It Demonstrates DCS Level 3

| DCS Concept | AWS Implementation |
|---|---|
| **Data encryption** | AES-256-GCM via OpenTDF CLI (client-side encryption) |
| **Key management** | AWS KMS wraps/unwraps DEKs; OpenTDF KAS manages key access |
| **Policy enforcement at decryption** | KAS evaluates ABAC policies before releasing DEK |
| **Labels bound to encrypted data** | TDF manifest contains labels, policies, and key references |
| **Federated key management** | Multiple KAS instances possible (one per nation account) |
| **Audit trail** | KAS logs every key access request; CloudTrail logs KMS operations |
| **Protection independent of infrastructure** | Even S3 admin or AWS root account cannot read TDF payloads |
| **Identity** | Cognito OIDC tokens with custom attributes, consumed via Claims ERS |

## The critical difference: why Level 3 matters

In Level 1 and Level 2, anyone with infrastructure access (S3 admin, AWS root) can read all data. Labels and policies are only enforced by the application.

In Level 3:

- Data is encrypted at the client before it ever reaches AWS
- Only the KAS can release the DEK needed to decrypt
- The KAS evaluates ABAC policies before releasing any key
- Even AWS itself cannot read the data — only users who pass KAS policy checks
- If you copy the TDF file to a USB drive, it remains encrypted and policy-protected
- If the S3 bucket is breached, attackers get only ciphertext

This is true data-centric security: protection travels with the data, independent of infrastructure.

## Components

### 1. OpenTDF Platform on ECS Fargate

The OpenTDF platform runs as a single Fargate task with a public IP, providing:

**Key Access Service (KAS)**:
- Receives DEK unwrap requests from client CLIs/SDKs
- Authenticates the requesting user via OIDC token (validated against Cognito's JWKS)
- Evaluates ABAC policy from the TDF manifest
- If authorized: unwraps DEK using AWS KMS and returns to client
- If denied: returns 403 with policy violation details
- Logs every request (authorized and denied)

**Attribute Service**:
- Manages the attribute namespace (clearance levels, nationalities, SAPs)
- Defines attribute hierarchy (SECRET > OFFICIAL > UNCLASSIFIED)
- Stores subject mappings that connect JWT claims to attribute entitlements

**Entity Resolution Service (Claims mode)**:
- Reads user attributes directly from JWT claims
- No callback to an external IdP required
- Maps Cognito's `custom:` prefixed claims to OpenTDF attributes via subject mappings

**Container image**: `ghcr.io/opentdf/platform:latest`

**Configuration** (environment variables):
```
OPENTDF_DB_HOST=<rds-endpoint>
OPENTDF_DB_PORT=5432
OPENTDF_DB_DATABASE=opentdf
OPENTDF_SERVER_AUTH_ISSUER=https://cognito-idp.<region>.amazonaws.com/<pool-id>
OPENTDF_SERVER_AUTH_AUDIENCE=http://localhost:8080
OPENTDF_SERVICES_ENTITYRESOLUTION_MODE=claims
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
      "Principal": { "AWS": "arn:aws:iam::role/dcs-level3-kas-task-role" },
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "*"
    }
  ]
}
```

**Why KMS**: Hardware-backed, FIPS 140-3 Level 3 validated, audit-logged via CloudTrail. The KEK never leaves the HSM.

### 3. Cognito User Pools (from Lab 2)

Handles authentication and attribute assertion for all coalition users. Reused directly from Lab 2 — no additional setup required.

**User pools**: One per nation (UK, Poland, US)

**Custom attributes** (included in OIDC ID tokens):
```json
{
  "sub": "a1b2c3d4-...",
  "custom:clearance": "SECRET",
  "custom:clearanceLevel": "2",
  "custom:nationality": "GBR",
  "custom:saps": "WALL",
  "cognito:username": "uk-analyst-01",
  "iss": "https://cognito-idp.eu-west-2.amazonaws.com/eu-west-2_aBcDeFgHi"
}
```

The OpenTDF platform validates these tokens against Cognito's JWKS endpoint and extracts the `custom:` claims for access decisions via subject mappings.

### 4. RDS PostgreSQL (db.t3.micro)

A single-AZ db.t3.micro instance in the default VPC. Free-tier eligible. Stores:

- **Attribute definitions**: The namespace of attributes (clearance, nationality, etc.)
- **Subject mappings**: Rules connecting JWT claims to attribute entitlements
- **Key access audit**: Log of every KAS request and decision

### 5. S3 Data Bucket

Stores TDF files. Unlike Level 1 and Level 2, the S3 bucket contains only ciphertext. No special S3 policies needed for access control because the data is self-protecting.

### 6. OpenTDF CLI (otdfctl)

Installed on user workstations. Available as npm package or Go binary.

**Encryption flow**:
```bash
otdfctl encrypt \
  --endpoint http://$KAS_IP:8080 \
  --oidc-endpoint $COGNITO_ISSUER \
  --client-id $CLIENT_ID \
  --username uk-analyst-01 \
  --password 'TempPass1!' \
  --attr "https://dcs.example.com/attr/classification/value/SECRET" \
  --attr "https://dcs.example.com/attr/releasable/value/GBR" \
  --input intel-report.txt \
  --output intel-report.txt.tdf
```

**Decryption flow**:
```bash
otdfctl decrypt \
  --endpoint http://$KAS_IP:8080 \
  --oidc-endpoint $COGNITO_ISSUER \
  --client-id $CLIENT_ID \
  --username uk-analyst-01 \
  --password 'TempPass1!' \
  --input intel-report.txt.tdf \
  --output intel-report-decrypted.txt
# If user lacks required attributes, this returns "access denied"
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
        "url": "http://KAS-IP:8080/kas",
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
  }
}
```

Security properties:

1. `wrappedKey` can only be unwrapped by the KAS specified in `url`
2. `policyBinding` prevents the policy from being tampered with after encryption
3. `rootSignature` on payload detects any data tampering
4. Even with the TDF file, you cannot decrypt without KAS authorization

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
| UK Cognito/IdP   |     | PL Cognito/IdP   |     | US Cognito/IdP   |
| UK policies      |     | PL policies      |     | US policies      |
| UK audit logs    |     | PL audit logs    |     | US audit logs    |
+------------------+     +------------------+     +------------------+
```

Each nation maintains sovereignty over their keys and access decisions.

## Estimated Cost

Approximately $15-25/month for demonstration:

- ECS Fargate: ~$10-15 (1 task, 0.5 vCPU, 1GB)
- RDS db.t3.micro: Free tier eligible (first 12 months), ~$15/month after
- KMS: ~$1/month per key + $0.03/10,000 requests
- Cognito: Free tier covers demo usage
- S3: minimal for demo data volumes

No ALB, no NAT gateway, no custom VPC — those were the biggest cost drivers in the previous architecture.
