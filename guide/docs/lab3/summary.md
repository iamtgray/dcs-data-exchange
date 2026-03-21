# What You Learned - Lab 3

## Key takeaways

### 1. Data is truly self-protecting

The TDF file contains encrypted data, a wrapped key, and an access policy. It doesn't matter where the file ends up: a USB drive, a cloud bucket, an email attachment. Without KAS authorization, the data is unreadable. This is the core promise of data-centric security.

### 2. The Key Access Server is the control plane

Whoever runs the KAS controls access to data. The KAS decides whether to release encryption keys based on the user's attributes and the data's policy. This is why federated KAS matters in coalition scenarios: each nation controls their own citizens' access through their own KAS.

### 3. Policy enforcement happens at decryption time

Policies aren't evaluated when data is stored or shared. They're evaluated every time someone tries to decrypt. This means you can change access to already-shared data by updating entitlements. Revoke someone's clearance, and every TDF they could previously read becomes inaccessible.

### 4. The TDF format combines all three DCS levels

A TDF file contains:
- Labels (Level 1): Security metadata in the manifest assertions
- Access control (Level 2): ABAC policy bound to the wrapped key
- Encryption (Level 3): AES-256-GCM encrypted payload with KAS-controlled key access

All three levels work together in a single package.

### 5. AWS KMS provides the trust anchor

The KMS key never leaves the hardware security module. It's the root of trust for the entire system. CloudTrail logs every key operation, providing a hardware-backed audit trail.

### 6. Protection is independent of infrastructure

This is the biggest difference from Levels 1 and 2. S3 admins, database admins, even AWS root account holders cannot read TDF-protected data. The encryption is applied before data reaches AWS and can only be removed through the KAS.

## The complete DCS picture

```
Level 1: LABEL the data
  "This is SECRET, releasable to GBR/USA/POL, requires WALL SAP"
     |
     v
Level 2: CONTROL access with policies
  "Check clearance >= classification AND nationality in releasable-to AND has required SAP"
     |
     v
Level 3: ENCRYPT so protection persists
  "Encrypt with AES-256, wrap key with KAS, only release after policy check"
     |
     v
Result: Data that protects itself wherever it goes
```

## What would come next in a real deployment

- Multiple KAS instances, one per nation, each with their own KMS key
- Federated identity via real SAML/OIDC federation between national identity providers
- Cryptographic label binding with STANAG 4778 JWS signatures binding labels to TDF manifests
- Gateway architecture for transition points between PKI (tactical) and TDF (strategic) systems
- Post-quantum migration using TDF's multi-KAS support to add post-quantum algorithms alongside classical ones
- Offline operations via asymmetric encryption mode for tactical scenarios without KAS connectivity

---

Congratulations on completing all three labs. Head to the **[Wrap-Up](../wrapup/index.md)** to compare the levels side by side and clean up your AWS resources.
