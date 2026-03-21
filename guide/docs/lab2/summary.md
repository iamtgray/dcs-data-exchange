# What You Learned - Lab 2

## Key takeaways

### 1. ABAC scales without an explosion of permissions

In traditional RBAC, you'd need roles like "UK-SECRET-WALL-reader" and "Polish-NS-no-SAP-reader" for every combination. With ABAC, three Cedar policies handle all combinations of clearance, nationality, and SAPs for any number of users and data items.

### 2. Policies are separate from code and data

Cedar policies live in the policy engine, not in your Lambda function. You can add, remove, or change policies without touching code. Data labels stay the same. This separation means security teams manage policies, development teams manage code, data owners manage labels, and nobody needs to coordinate for routine policy changes.

### 3. Dynamic policy changes take effect immediately

When you added Sweden's temporary access, it worked instantly across all data items. When you removed it, access was revoked just as fast. This matters for real operations where access requirements change frequently.

### 4. The policy engine explains its decisions

Verified Permissions tells you which specific policy allowed or denied a request. This makes auditing straightforward: you can trace exactly why every access decision was made.

### 5. Classification mapping works across systems

UK SECRET, Polish NATO-SECRET, and US IL-6 all map to clearance level 2. The numeric mapping lets Cedar compare clearances across different national systems without hard-coding every combination.

## What's still missing

### Data is still unencrypted

The biggest gap: DynamoDB stores all payloads in plain text. Anyone with direct DynamoDB access (database admin, AWS root account, a compromised IAM credential with DynamoDB permissions) can read everything. The ABAC policies are only enforced by our Lambda - they're not enforced at the data layer.

### No cryptographic binding of labels

Labels are DynamoDB attributes that anyone with write access can change. There's no digital signature proving that the originator set these labels. In a real system, labels would be cryptographically bound to the data (STANAG 4778).

### Protection doesn't travel with the data

If someone exports the DynamoDB table or copies data to another system, the labels might follow (as attributes) but the policy enforcement won't. The Cedar policies only apply within our system.

## Moving to Level 3

Lab 3 solves all of these problems:

- Data is encrypted before it reaches storage, so even admins can't read it
- Labels are cryptographically bound to the encrypted data in the TDF manifest
- Protection travels with the data because the TDF file carries its own encryption, labels, and policy references
- Policy is enforced at decryption time by the Key Access Server, not by the application

---

Ready for the final level? Continue to **[Lab 3: Encryption (DCS Level 3)](../lab3/index.md)**.
