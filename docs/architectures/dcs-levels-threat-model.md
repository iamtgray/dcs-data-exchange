# DCS Levels 1, 2, 3: Threat Model

## Scope

This threat model analyses how a threat actor with existing access to the AWS environment could compromise the data-centric security controls at each DCS maturity level. The assumed attacker profile is an insider or a compromised account -- someone who has legitimate AWS credentials but is attempting to access data beyond their authorisation, circumvent security controls, or undermine the DCS architecture.

This is distinct from external network attacks (which are mitigated by AWS infrastructure security). The focus here is on threats that exploit the gap between having AWS access and having authorised data access.

## Threat Actor Profiles

### TA-1: Compromised User Account
An external attacker who has obtained valid AWS credentials (e.g., through phishing, credential stuffing, or stolen access keys). They have the permissions of whichever user or role was compromised.

### TA-2: Malicious Insider (Low Privilege)
A legitimate user with OFFICIAL clearance who attempts to access SECRET or TOP SECRET data. They have their own IAM credentials and understand the system architecture.

### TA-3: Malicious Insider (High Privilege)
A legitimate user with elevated AWS permissions (e.g., a developer or administrator) who has broad IAM access but should not have unrestricted access to classified data.

### TA-4: Compromised Lambda / Application
The Lambda function or application code is compromised (e.g., dependency supply chain attack, code injection). The attacker can execute arbitrary code within the Lambda execution context.

---

## DCS Level 1: Threats to Basic Labelling

### T1.1: Upload Without Labels (Bypass Validation)

**Threat:** An attacker uploads objects directly to S3 without tags, and reads them back before the Lambda validation function triggers (race condition). S3 Event Notifications are asynchronous -- there is a window of seconds between upload and quarantine.

**Impact:** Data exists briefly without labels. If the attacker reads it back immediately, they bypass the labelling requirement.

**Likelihood:** Medium. The window is small (typically under 5 seconds) but exploitable with scripting.

**Mitigation:**
- **S3 Object Lambda** or **S3 Access Points** could intercept reads and check tags before returning data. This provides synchronous validation on read rather than async validation on write.
- **S3 Bucket Policy** with `Deny` for `s3:PutObject` unless specific tag keys are present. AWS supports `s3:RequestObjectTag/<key>` conditions:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::bucket/*",
  "Condition": {
    "StringNotLike": {
      "s3:RequestObjectTagKey/Classification": "*"
    }
  }
}
```
This is a preventive control (blocks unlabelled uploads) vs the current reactive control (quarantines after upload).

- **SCP (Service Control Policy)** at the AWS Organization level to enforce tagging across all accounts.

**Residual risk after mitigation:** Low. Preventive S3 bucket policy blocks uploads without tags synchronously.

### T1.2: Classification Downgrade via Tag Modification

**Threat:** An attacker with `s3:PutObjectTagging` permission changes an object's `Classification` tag from `SECRET` to `OFFICIAL`, or modifies `ReleasableTo` to include their nation.

**Impact:** Object appears to be at a lower classification than it actually is. Downstream systems that rely on labels for access control will make incorrect decisions.

**Likelihood:** High if the attacker has `s3:PutObjectTagging` permission. This is the fundamental weakness of DCS-1 -- labels are not cryptographically bound to data.

**Mitigation:**
- **Restrict `s3:PutObjectTagging`** to a dedicated labelling service role. No human users should have this permission on the data bucket.
- **S3 Object Lock** (Governance mode) can prevent tag modifications.
- **CloudTrail monitoring** with alarms on `PutObjectTagging` events to detect tag changes.
- **EventBridge rule** triggering a Lambda that compares current tags against a DynamoDB catalog of original tags (detect drift).
- **Ultimately, this is why DCS-3 exists.** Labels alone (DCS-1) are insufficient for high-assurance environments. Cryptographic binding (HMAC in DCS-3) is the definitive mitigation.

**Residual risk after mitigation:** Medium. Monitoring detects changes but cannot prevent them in real-time without Object Lock. DCS-3 provides the cryptographic backstop.

### T1.3: Lambda Function Bypass

**Threat:** An attacker disables the S3 event notification, modifies the Lambda function code, or deletes the Lambda function entirely. Without the validation function, objects are never checked.

**Impact:** Complete loss of labelling validation. Non-compliant objects persist in the data bucket.

**Likelihood:** Low-Medium. Requires IAM permissions to modify Lambda or S3 notification configuration.

**Mitigation:**
- **SCPs** to deny `lambda:DeleteFunction`, `lambda:UpdateFunctionCode`, `s3:PutBucketNotification` for all principals except the Terraform deployment role.
- **AWS Config rule** to monitor that the S3 notification configuration remains intact.
- **CloudTrail alarm** on any modification to the Lambda function or S3 bucket notification.
- **Separate AWS account** for the validation infrastructure (cross-account Lambda invocation) so the data account cannot modify the validation logic.

**Residual risk after mitigation:** Low with SCPs and monitoring.

### T1.4: Quarantine Bucket Access

**Threat:** An attacker accesses the quarantine bucket to retrieve non-compliant (potentially sensitive) objects that were quarantined.

**Impact:** Access to data that failed validation -- which may still contain classified information even without labels.

**Mitigation:**
- **Strict IAM policy** on the quarantine bucket: only the Security Administrator role and the Lambda execution role can access it.
- **S3 bucket policy** denying all access except from specific IAM roles.
- **SSE-S3 or SSE-KMS** encryption on the quarantine bucket.

**Residual risk after mitigation:** Low.

---

## DCS Level 2: Threats to ABAC and Enhanced Labelling

### T2.1: Direct S3 Access Bypassing the Access Broker

**Threat:** An attacker ignores the API Gateway/Lambda access broker and accesses S3 directly using their AWS credentials. The access broker provides application-level ABAC, but if the attacker can reach S3 directly, they bypass it.

**Impact:** ABAC enforcement is circumvented. The attacker accesses any object their IAM role has S3 permissions for, regardless of classification matching.

**Likelihood:** High. This is the most significant threat at DCS-2. Anyone with `s3:GetObject` permission on the bucket can bypass the access broker.

**Mitigation:**
- **S3 bucket policy** that denies all `s3:GetObject` except from the Lambda execution role and persona roles (which are only assumable by the Lambda). This ensures all human access goes through the broker:

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::bucket/*",
  "Condition": {
    "StringNotEquals": {
      "aws:PrincipalArn": [
        "arn:aws:iam::ACCOUNT:role/dcs-level-2-dev-lambda-access-broker",
        "arn:aws:iam::ACCOUNT:role/dcs-level-2-dev-uk-secret-analyst",
        "arn:aws:iam::ACCOUNT:role/dcs-level-2-dev-nato-official-analyst",
        "arn:aws:iam::ACCOUNT:role/dcs-level-2-dev-uk-top-secret-analyst"
      ]
    }
  }
}
```

- **VPC endpoint policy** restricting S3 access to only go through the VPC endpoint, preventing direct internet access.
- **This is fundamentally why DCS-3 exists.** DCS-2 access controls rely on the enforcement layer being in the path. DCS-3 makes the data itself the enforcement layer.

**Residual risk after mitigation:** Medium. Bucket policy reduces the attack surface but adds operational complexity. An admin who can modify the bucket policy can grant themselves access.

### T2.2: IAM Role Assumption by Unauthorised Principal

**Threat:** An attacker assumes a persona role with a higher clearance than their own. For example, an OFFICIAL-cleared user assumes the `uk-top-secret-analyst` role to gain TOP_SECRET access.

**Impact:** Privilege escalation. The attacker gains access to data above their clearance level.

**Likelihood:** Medium. Depends on the role trust policy. In the current implementation, the trust policy allows the account root to assume any role, meaning any IAM principal in the account can assume any persona role.

**Mitigation:**
- **Restrict the role trust policy** to only the Lambda execution role (remove account root):

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT:role/lambda-access-broker"
  }
}
```

- **STS condition keys** to restrict who can assume each role:
  - `aws:PrincipalTag/Clearance` condition on the trust policy
  - `sts:TransitiveTagKeys` to prevent session tag manipulation

- **In production**, use an identity provider (IdP) with SAML/OIDC federation. Users authenticate via the IdP, which asserts their clearance level. The IdP-asserted tags cannot be manipulated by the user.

**Residual risk after mitigation:** Low with IdP federation. Medium without it.

### T2.3: DynamoDB Audit Log Tampering

**Threat:** An attacker with DynamoDB write access modifies or deletes audit records to cover their tracks.

**Impact:** Loss of audit integrity. Cannot detect or investigate unauthorised access.

**Likelihood:** Medium. Requires DynamoDB write permissions.

**Mitigation:**
- **DynamoDB table resource policy** restricting write access to the Lambda execution role only.
- **DynamoDB Point-in-Time Recovery** enables restoring the table to any point in time.
- **DynamoDB Streams** piped to a separate, write-once audit store (e.g., S3 with Object Lock, or Amazon QLDB for immutable ledger).
- **CloudTrail Data Events** for DynamoDB as a secondary audit trail that cannot be modified by the application.

**Residual risk after mitigation:** Low with immutable secondary audit store.

### T2.4: Tag Manipulation for ABAC Bypass

**Threat:** Same as T1.2 but now with ABAC consequences. An attacker modifies an object's `Classification` tag from `TOP_SECRET` to `OFFICIAL`, allowing lower-cleared users to access it via the IAM ABAC condition `s3:ExistingObjectTag/Classification`.

**Impact:** Classification downgrade enables unauthorised access through the legitimate ABAC path.

**Likelihood:** High if the attacker has `s3:PutObjectTagging` permission.

**Mitigation:**
- Same as T1.2: restrict `PutObjectTagging`, use Object Lock, monitor via CloudTrail.
- **DCS-3 HMAC signing** detects metadata tampering cryptographically.
- **Compare S3 tags against DynamoDB MEM catalog** as a reconciliation check.

**Residual risk after mitigation:** Medium without DCS-3. Low with DCS-3.

### T2.5: API Gateway Abuse

**Threat:** The API Gateway has no authentication (`authorization = "NONE"`). An attacker who discovers the URL can make access requests for any persona without proving their identity.

**Impact:** Anyone with the API URL can impersonate any persona.

**Likelihood:** High in the current demo configuration.

**Mitigation:**
- **IAM authorisation** on the API Gateway: require SigV4-signed requests.
- **Cognito User Pool** authoriser with groups mapped to personas.
- **API key** with usage plan (minimum viable for a demo).
- **WAF** on the API Gateway to rate-limit and block abuse.
- **In production**, the "persona" would not be a request parameter but would be derived from the authenticated user's identity token.

**Residual risk after mitigation:** Low with IAM or Cognito auth.

---

## DCS Level 3: Threats to Cryptographic Protection

### T3.1: KMS Key Policy Modification

**Threat:** An attacker with `kms:PutKeyPolicy` permission modifies the key policy to remove the ABAC condition, allowing any principal to decrypt. Or they add their own IAM role to the policy.

**Impact:** Complete bypass of cryptographic access control. All data encrypted with that key becomes accessible.

**Likelihood:** Low. Requires KMS administrative permissions. However, the current key policy grants `kms:*` to the account root, which means anyone who can escalate to admin can modify key policies.

**Mitigation:**
- **Remove `kms:*` from account root** in the key policy. Instead, create a dedicated Key Custodian role and grant only that role `kms:PutKeyPolicy`:

```json
{
  "Sid": "AllowKeyAdministration",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT:role/dcs-key-custodian"
  },
  "Action": [
    "kms:PutKeyPolicy",
    "kms:DescribeKey",
    "kms:EnableKeyRotation",
    "kms:ScheduleKeyDeletion"
  ],
  "Resource": "*"
}
```

- **SCP** denying `kms:PutKeyPolicy` for all principals except the Key Custodian role.
- **CloudTrail alarm** on any `PutKeyPolicy` event.
- **Multi-party approval** for key policy changes (using AWS Organizations management account approval or a CI/CD pipeline with mandatory review).

**Residual risk after mitigation:** Low with SCP + dedicated Key Custodian.

### T3.2: Compromised Lambda Encrypt Function

**Threat:** The encrypt Lambda (TA-4) is compromised. The attacker modifies it to exfiltrate plaintext before encryption, or to encrypt data with the wrong key (using the OFFICIAL key for TOP_SECRET data), or to skip HMAC signing.

**Impact:** Plaintext data leakage. Incorrect cryptographic protection. Loss of metadata integrity verification.

**Likelihood:** Low-Medium. Requires Lambda modification access or a supply chain attack on dependencies.

**Mitigation:**
- **Lambda code signing** with AWS Signer to prevent deploying unsigned code.
- **Immutable deployment pipeline** where only the CI/CD system (with code review) can update Lambda.
- **SCP** denying `lambda:UpdateFunctionCode` for all principals except the deployment role.
- **Runtime monitoring** via Lambda extensions or CloudWatch anomaly detection to detect unusual behaviour (e.g., outbound network calls from the encrypt Lambda).
- **Separate encrypt and audit** responsibilities: have a second Lambda verify that every encrypted object has a valid HMAC and correct KMS key for its classification.

**Residual risk after mitigation:** Low with code signing + immutable deployment.

### T3.3: Compromised Lambda Decrypt Function

**Threat:** The decrypt Lambda is compromised. The attacker modifies it to:
- Skip the HMAC integrity check (allowing tampered metadata to pass)
- Return plaintext to unauthorised callers regardless of persona
- Log plaintext to an attacker-controlled location
- Assume higher-clearance roles than requested

**Impact:** Complete bypass of application-level access control and integrity verification. However, KMS key policy is still enforced independently.

**Likelihood:** Low-Medium. Same as T3.2.

**Mitigation:**
- Same as T3.2: code signing, immutable deployment, SCPs.
- **Critical observation:** Even with a compromised decrypt Lambda, the KMS key policy remains enforced. The Lambda execution role (`lambda_decrypt`) does NOT have `kms:Decrypt` permission directly -- it must assume a persona role, and the persona role's clearance tag must match the key policy. So:
  - If the Lambda tries to call KMS Decrypt using its own role, it fails (no KMS permissions).
  - If the Lambda assumes `nato-official-analyst` role and tries to decrypt a SECRET object, KMS still denies because the role's `Clearance=OFFICIAL` tag doesn't match the `dcs-secret-key` policy.
  - The attacker can only decrypt data that the highest-clearance persona role can access, which is the TOP_SECRET analyst.

- **Further mitigation:** Restrict which persona roles the Lambda can assume based on context (e.g., AWS VPC endpoint policies, or a separate authorisation service that issues short-lived STS tokens).

**Residual risk after mitigation:** Medium. The KMS key policy provides a cryptographic floor, but a compromised Lambda could impersonate the TOP_SECRET analyst role.

### T3.4: Encryption Context Manipulation

**Threat:** An attacker calls the encrypt Lambda with mismatched classification/plaintext. For example, submitting TOP SECRET data but specifying `classification: "OFFICIAL"`. The data gets encrypted with the weaker `dcs-official-key`, making it accessible to OFFICIAL-cleared users.

**Impact:** Data encrypted with an inappropriate key, exposing it to users with insufficient clearance.

**Likelihood:** Medium. Depends on whether the caller is trusted to correctly classify data.

**Mitigation:**
- **Content inspection** before encryption: an automated classification service (DLP, regex, ML-based) that validates the claimed classification against the content.
- **Mandatory review workflow**: data producers submit classification requests that are approved by a security officer before encryption proceeds.
- **Post-encryption audit**: periodic sampling of encrypted objects, decrypting and verifying the classification is appropriate for the content.
- **This is fundamentally a data governance problem, not a cryptographic one.** The encryption system correctly enforces whatever classification is asserted; the threat is incorrect assertion.

**Residual risk after mitigation:** Medium. Automated content inspection reduces risk but cannot eliminate deliberate misclassification by a determined insider.

### T3.5: HMAC Bypass via New Encryption

**Threat:** An attacker who has `kms:Encrypt` permission on a key calls KMS directly (outside the Lambda) to re-encrypt an object with a new HMAC computed over modified metadata. They then overwrite the S3 object with the new ciphertext and matching HMAC.

**Impact:** The HMAC integrity check passes despite metadata having been changed, because the attacker generated a new, valid HMAC for the modified metadata.

**Likelihood:** Low. Requires `kms:Encrypt` on the appropriate key AND `s3:PutObject` on the data bucket.

**Mitigation:**
- **Restrict `kms:Encrypt` and `kms:GenerateDataKey`** to the Lambda encrypt role only. No persona roles or human users should have encrypt permissions.
- **S3 bucket policy** denying `s3:PutObject` except from the Lambda encrypt role.
- **S3 Object Lock** (Compliance mode) to prevent overwrites entirely.
- **Append-only storage**: write once, never overwrite. New versions create new objects.
- **Provenance chain** in the audit table: every object key is logged at encryption time. An overwritten object would have mismatched creation timestamps.

**Residual risk after mitigation:** Low with S3 Object Lock + restricted encrypt permissions.

### T3.6: KMS Key Deletion / Scheduling Deletion

**Threat:** An attacker with `kms:ScheduleKeyDeletion` permission schedules a KMS key for deletion. After the waiting period (minimum 7 days), all data encrypted with that key becomes permanently unrecoverable.

**Impact:** Permanent data loss for all objects encrypted with the deleted key. Denial-of-service against the data.

**Likelihood:** Low. Requires administrative KMS permissions.

**Mitigation:**
- **SCP** denying `kms:ScheduleKeyDeletion` for all principals except a break-glass role.
- **CloudTrail alarm** with immediate notification on `ScheduleKeyDeletion` events.
- **Multi-region key replication** to survive regional key deletion.
- **KMS key deletion waiting period** set to maximum (30 days) to provide time for detection and cancellation via `kms:CancelKeyDeletion`.

**Residual risk after mitigation:** Low with SCP + 30-day deletion window + monitoring.

### T3.7: Plaintext in Lambda Memory

**Threat:** During encryption and decryption, plaintext data exists in Lambda memory. An attacker with access to Lambda debugging, X-Ray tracing, or memory dumps could extract plaintext.

**Impact:** Plaintext data exposure bypassing all cryptographic controls.

**Likelihood:** Low. Lambda memory is not directly accessible via AWS APIs. However, if Lambda extensions or layers are compromised, they share the execution environment.

**Mitigation:**
- **No Lambda extensions** in the encryption/decryption functions.
- **No X-Ray tracing** on sensitive Lambda functions.
- **Lambda reserved concurrency** to limit the attack surface.
- **VPC-isolated Lambda** with no internet egress to prevent data exfiltration.
- **Zero plaintext after use**: the Python code explicitly sets the plaintext variable to `None` after use (though Python garbage collection timing is not guaranteed).
- **For highest assurance**, use AWS Nitro Enclaves for the cryptographic operations, providing hardware-isolated memory.

**Residual risk after mitigation:** Low with VPC isolation and no extensions. Very low with Nitro Enclaves.

---

## Cross-Level Threats

### TC.1: Terraform State File Exposure

**Threat:** The Terraform state file contains sensitive information: KMS key ARNs, IAM role ARNs, S3 bucket names, Lambda environment variables (including KMS key IDs). If the state file is stored locally or in an unencrypted S3 backend, an attacker who accesses it gains comprehensive knowledge of the architecture.

**Impact:** Information disclosure. The attacker knows all resource identifiers, enabling targeted attacks against specific components.

**Likelihood:** Medium. State files are often stored insecurely in development environments.

**Mitigation:**
- **Remote state backend** in S3 with SSE-KMS encryption and versioning.
- **DynamoDB state locking** to prevent concurrent modifications.
- **IAM policy** restricting state bucket access to the deployment pipeline only.
- **State file does not contain secrets** (KMS key material is never in state; only ARNs and metadata).

### TC.2: CloudTrail Tampering

**Threat:** An attacker disables CloudTrail or deletes CloudTrail logs to cover their tracks after performing unauthorized KMS operations.

**Impact:** Loss of audit trail. Cannot detect or investigate unauthorized cryptographic operations.

**Likelihood:** Low-Medium. Requires CloudTrail administrative permissions.

**Mitigation:**
- **SCP** denying `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail` for all principals.
- **CloudTrail log file validation** enabled (detects log file tampering).
- **CloudTrail logs** delivered to a separate security account that the application account cannot access.
- **S3 Object Lock** on the CloudTrail log bucket.

### TC.3: IAM Privilege Escalation

**Threat:** An attacker escalates their IAM privileges to gain access to KMS keys, Lambda functions, or S3 buckets that they should not have access to. Common escalation paths: `iam:CreateRole`, `iam:AttachRolePolicy`, `iam:PassRole`, `sts:AssumeRole` wildcards.

**Impact:** Full compromise of all DCS levels.

**Likelihood:** Medium. IAM privilege escalation is one of the most common AWS attack vectors.

**Mitigation:**
- **Permission boundaries** on all IAM roles to cap maximum permissions.
- **SCP** denying IAM mutation actions (`iam:Create*`, `iam:Attach*`, `iam:Put*`) except from the deployment pipeline.
- **IAM Access Analyzer** to detect overly permissive policies.
- **Regular IAM credential rotation** and removal of unused roles.
- **Separate accounts** for development, security infrastructure, and data processing (AWS Organizations with SCPs).

### TC.4: Supply Chain Attack on Lambda Dependencies

**Threat:** A malicious dependency is introduced into the Lambda function code (e.g., compromised Python package in the Level 3 Lambda layer for the `cryptography` library).

**Impact:** Arbitrary code execution in the Lambda context, potentially leading to plaintext exfiltration or key material theft.

**Likelihood:** Low-Medium. Supply chain attacks are increasing in frequency.

**Mitigation:**
- **Minimal dependencies**: Level 1 and 2 Lambdas use only `boto3` (built into Lambda runtime). Level 3 uses `boto3` for the simplified KMS-direct mode.
- **Pin dependency versions** and verify checksums.
- **Private PyPI mirror** for approved packages.
- **Lambda code signing** with AWS Signer.
- **SCA scanning** (Software Composition Analysis) in the CI/CD pipeline.

---

## Threat Summary Matrix

| ID | Threat | DCS Level | Likelihood | Impact | Key Mitigation | Residual Risk |
|----|--------|-----------|-----------|--------|----------------|---------------|
| T1.1 | Upload without labels (race condition) | 1 | Medium | Medium | Preventive S3 bucket policy on PutObject | Low |
| T1.2 | Tag modification (classification downgrade) | 1 | High | High | Restrict PutObjectTagging + DCS-3 HMAC | Medium (Low with DCS-3) |
| T1.3 | Lambda/notification bypass | 1 | Low-Med | High | SCPs + Config rules + monitoring | Low |
| T1.4 | Quarantine bucket access | 1 | Low | Medium | Strict IAM + bucket policy | Low |
| T2.1 | Direct S3 access bypassing broker | 2 | High | High | S3 bucket policy deny + DCS-3 | Medium (Low with DCS-3) |
| T2.2 | Unauthorised role assumption | 2 | Medium | High | Restrict trust policy + IdP federation | Low with IdP |
| T2.3 | Audit log tampering | 2 | Medium | Medium | Immutable audit store + CloudTrail | Low |
| T2.4 | Tag manipulation for ABAC bypass | 2 | High | High | Same as T1.2 + DCS-3 | Medium (Low with DCS-3) |
| T2.5 | Unauthenticated API access | 2 | High | High | IAM/Cognito auth on API GW | Low |
| T3.1 | KMS key policy modification | 3 | Low | Critical | SCP + Key Custodian role + alarm | Low |
| T3.2 | Compromised encrypt Lambda | 3 | Low-Med | High | Code signing + immutable deploy | Low |
| T3.3 | Compromised decrypt Lambda | 3 | Low-Med | High | Code signing + KMS policy is independent floor | Medium |
| T3.4 | Misclassification at encryption | 3 | Medium | High | Content inspection + governance | Medium |
| T3.5 | HMAC bypass via re-encryption | 3 | Low | High | Restrict encrypt perms + Object Lock | Low |
| T3.6 | KMS key deletion | 3 | Low | Critical | SCP + 30-day window + alarm | Low |
| T3.7 | Plaintext in Lambda memory | 3 | Low | High | VPC isolation + no extensions + Nitro | Low |
| TC.1 | Terraform state exposure | All | Medium | Medium | Encrypted remote backend | Low |
| TC.2 | CloudTrail tampering | All | Low-Med | High | SCP + separate account + Object Lock | Low |
| TC.3 | IAM privilege escalation | All | Medium | Critical | Permission boundaries + SCPs + analyzer | Low-Med |
| TC.4 | Supply chain attack | All | Low-Med | High | Minimal deps + signing + SCA | Low |

---

## Key Architectural Insights

### DCS Levels as Defence-in-Depth

The threat model reveals a clear pattern: many DCS-1 and DCS-2 threats are mitigated or eliminated by DCS-3.

| Threat Category | DCS-1 | DCS-2 | DCS-3 |
|----------------|-------|-------|-------|
| Tag/label tampering | VULNERABLE (T1.2) | VULNERABLE (T2.4) | DETECTED by HMAC (AC3) |
| Bypassing access broker | N/A | VULNERABLE (T2.1) | PROTECTED by KMS key policy |
| Unauthorised role assumption | N/A | VULNERABLE (T2.2) | KMS key policy is independent check |
| Data exfiltration via S3 copy | VULNERABLE | VULNERABLE | PROTECTED (ciphertext without KMS access) |

This validates the ACP-240 maturity model: DCS-1 and DCS-2 provide operational benefits (labelling, ABAC, audit) but do not provide the assurance that DCS-3 offers (ACP-240 para 202: "DCS-1 and 2, whilst offering some benefits, do not provide the greater levels of information protection or assurance that DCS-3 offers").

### The Residual Risk at DCS-3

Even at DCS-3, two threats remain at medium residual risk:

1. **T3.3 (Compromised decrypt Lambda)**: A compromised Lambda can impersonate the highest-clearance persona role. Mitigation: Nitro Enclaves, code signing, and restricting the Lambda to assume only specific roles based on authenticated caller context.

2. **T3.4 (Misclassification)**: The encryption system enforces whatever classification is asserted. If an insider deliberately misclassifies TOP SECRET data as OFFICIAL, the crypto is correct but the classification is wrong. This is a governance problem, not a technical one.

### Recommendations for Production

1. **Deploy DCS-3 as the baseline** for any data that requires actual protection. DCS-1 and DCS-2 are valuable for compliance and operational efficiency but are not sufficient for high-assurance data protection.

2. **Use an identity provider** (Cognito, ADFS, Okta) for user authentication. Remove the "persona" request parameter and derive clearance from IdP-asserted attributes.

3. **Separate AWS accounts** for: (a) data storage, (b) encryption/decryption services, (c) audit and monitoring, (d) key management. This limits blast radius of any single account compromise.

4. **SCPs are essential.** Many mitigations depend on Service Control Policies to prevent administrative actions. Without SCPs, a sufficiently privileged insider can bypass any control.

5. **Implement the full ZTDF format** (ACP-240 SUPP-1) for production DCS-3. The AWS KMS demo shows the concepts, but ZTDF provides standardised interoperability, federated KAS, and the full metadata binding mechanism per STANAG 4778.
