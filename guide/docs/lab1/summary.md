# What You Learned - Lab 1

## Key takeaways

### 1. Labels make data self-describing

By adding S3 tags to each object, the data now carries its own security metadata. Any system that reads those tags knows how to handle the data: what classification it is, who can see it, and what special access is needed.

### 2. Access decisions come from comparing attributes

Instead of writing a separate permission for every user-object combination, we wrote one function that compares user attributes against data labels. This is the core DCS concept: security decisions are driven by the data's metadata.

### 3. Classification mapping enables interoperability

The Polish analyst had "NATO-SECRET" and the UK analyst had "SECRET" -- different labels from different systems. By mapping them to a common numeric level, we enabled cross-national access decisions. This is what STANAG 4774 does at the NATO level.

### 4. Audit trails are built in

Every access decision was logged with full context. An auditor can reconstruct exactly who accessed what, when, and why the decision was made.

## What's missing (and why you need Level 2 and Level 3)

### Labels can be tampered with

Anyone with S3 PutObjectTagging permission can change a label from `SECRET` to `UNCLASSIFIED`. There's no cryptographic binding; the labels are just metadata that the system trusts. In a real DCS implementation, STANAG 4778 binds labels to data using digital signatures.

### Access control depends on the application

Our Lambda authorizer enforces the labels. But anyone with direct S3 access can download `operation-wall.txt` and read it, completely bypassing our authorizer. The data itself isn't protected.

### Policies are in code, not in a policy engine

The access logic is hard-coded in the Lambda function. If we want to add a new rule (e.g., "during exercise IRON SHIELD, grant temporary access to Swedish personnel"), we need to change code and redeploy.

### No encryption

The data is stored in plain text in S3. Anyone with S3 access, including AWS support or an attacker who compromises your account, can read everything.

## Moving to Level 2

Lab 2 addresses the first three problems:

- Policies move from hard-coded Lambda logic to a proper policy engine (Amazon Verified Permissions)
- User attributes come from dedicated identity providers (Cognito) rather than IAM tags
- Policies are declarative and dynamic, so you can change them without touching code

## Moving to Level 3

Lab 3 addresses the encryption problem:

- Data is encrypted before it reaches S3, so S3 only stores ciphertext
- A Key Access Server checks policies before releasing decryption keys
- Even infrastructure administrators cannot read the data without KAS authorization
- Protection persists even if the data is copied to a USB drive or another system

---

Ready for the next level? Continue to **[Lab 2: Access Control (DCS Level 2)](../lab2/index.md)**.
