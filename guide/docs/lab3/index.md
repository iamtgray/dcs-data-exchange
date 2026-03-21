# Lab 3: Encryption (DCS Level 3)

## What you'll build

In this lab, you'll deploy a full DCS Level 3 system:

1. **OpenTDF platform** running on ECS Fargate - the Key Access Server (KAS) that controls data encryption keys
2. **AWS KMS** as the root key store - hardware-backed keys that never leave the HSM
3. **Keycloak** as the identity provider - authenticates users and asserts their attributes
4. **OpenTDF SDK** on your workstation - encrypts and decrypts TDF files

This is the full stack. Data is encrypted before it leaves your machine. The only way to decrypt is through the KAS, which checks your attributes against the data's policy. Even AWS administrators can't read the data.

## What's different from Labs 1 and 2

| Aspect | Lab 1 | Lab 2 | Lab 3 |
|--------|-------|-------|-------|
| Can S3/DB admin read data? | Yes | Yes | **No** |
| Can AWS root read data? | Yes | Yes | **No** |
| Protection after data is copied? | No | No | **Yes** |
| Labels bound to data? | No (advisory tags) | No (DB attributes) | **Yes** (cryptographic binding in TDF) |
| Policy enforced by | Lambda code | Policy engine | **KAS at decryption time** |

## Architecture

```
Your Workstation
  |
  | OpenTDF SDK encrypts data locally
  | Creates .tdf file with:
  |   - encrypted payload (AES-256-GCM)
  |   - wrapped DEK (wrapped by KAS/KMS)
  |   - ABAC policy
  |   - security labels
  |
  v
S3 Bucket (stores .tdf files - only ciphertext)
  |
  | When someone wants to read the data...
  v
OpenTDF SDK on their workstation
  |
  | Sends wrapped DEK + user's OIDC token to KAS
  v
KAS (on ECS Fargate)
  |
  | 1. Validates OIDC token (via Keycloak)
  | 2. Checks user attributes against TDF policy
  | 3. If authorized: unwraps DEK using KMS
  | 4. Returns DEK to SDK
  v
SDK decrypts the data locally
```

## Before you start

- AWS Console access with admin permissions
- Same region as previous labs
- Docker installed on your workstation (for running OpenTDF SDK tools)
- About 60 minutes
- This lab costs more to run (~$3-5/day) because of ECS tasks and RDS

!!! warning "Cost"
    This lab runs ECS Fargate tasks and an RDS database that cost money per hour. Make sure to clean up when you're done (see the Wrap-Up section).

## Concepts for this lab

- **Data Encryption Key (DEK)**: A unique AES-256 key generated for each piece of data. The DEK encrypts the actual data.

- **Key Encryption Key (KEK)**: An AWS KMS key that wraps (encrypts) the DEK. The KEK never leaves the KMS hardware module.

- **Wrapped DEK**: The DEK encrypted by the KEK. Stored in the TDF manifest alongside the encrypted data. Useless without KAS authorization to unwrap it.

- **TDF file**: A ZIP archive containing the encrypted payload and a manifest with the wrapped DEK, access policy, and security labels.

Let's build it. **[Step 1: Set Up the Network](step1-vpc.md)**
