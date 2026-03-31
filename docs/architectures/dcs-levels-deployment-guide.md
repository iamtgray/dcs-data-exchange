# DCS Levels 1, 2, 3: Deployment and Demonstration Guide

This guide provides end-to-end instructions for deploying, demonstrating, and verifying DCS compliance across all three maturity levels on AWS. Each level builds on the previous, progressively implementing the DCS capabilities defined in ACP-240.

## Prerequisites

### Tools Required
- **Terraform** >= 1.5 (infrastructure provisioning)
- **AWS CLI** v2 (testing and verification)
- **jq** (JSON output parsing)
- **curl** (API testing)

### AWS Account Setup
- An AWS account with administrative access
- AWS CLI configured with credentials (`aws configure`)
- Sufficient permissions to create: S3 buckets, Lambda functions, IAM roles, KMS keys, DynamoDB tables, API Gateway, SNS topics, CloudWatch log groups

### Recommended Approach
Deploy the levels sequentially. Each level is independently deployable, but they are designed to be demonstrated in order to tell a coherent DCS maturity story:

1. **DCS-1**: "We can label all our data" -- reactive validation and quarantine
2. **DCS-2**: "We can control who accesses what based on labels" -- ABAC enforcement
3. **DCS-3**: "Even if someone bypasses access controls, the data is encrypted" -- cryptographic protection

---

## DCS Level 1: Basic Labelling

### What This Demonstrates

DCS-1 per ACP-240 para 197: the majority of new data is labelled with classification and releasability markings aligned to STANAG 4774. Objects without valid labels are automatically detected, quarantined, and reported.

**Key ACP-240 requirements demonstrated:**
- Data tagged with handling information (classification, releasability)
- Basic labelling aligned to STANAG 4774 confidentiality metadata label syntax
- Automated compliance validation

### Deploy

```bash
cd architectures/dcs-level-1-aws-labeling/terraform

# Optionally set notification email for SNS alerts
export TF_VAR_notification_email="security-admin@example.com"

terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

Save the outputs for testing:
```bash
DATA_BUCKET=$(terraform output -raw data_bucket_name)
QUARANTINE_BUCKET=$(terraform output -raw quarantine_bucket_name)
LAMBDA_NAME=$(terraform output -raw lambda_function_name)
SNS_TOPIC=$(terraform output -raw sns_topic_arn)
LOG_GROUP=$(terraform output -raw cloudwatch_log_group)

echo "Data bucket: $DATA_BUCKET"
echo "Quarantine bucket: $QUARANTINE_BUCKET"
```

If you provided a notification email, confirm the SNS subscription via the email link.

### Demonstrate

#### Test 1: Compliant Upload (Positive Test)

Upload an object with valid STANAG 4774-aligned labels:

```bash
# Create a test file
echo "SECRET intelligence report content" > /tmp/test-report.txt

# Upload with valid classification labels
aws s3api put-object \
  --bucket "$DATA_BUCKET" \
  --key "reports/intel-report-001.txt" \
  --body /tmp/test-report.txt \
  --tagging "Classification=SECRET&ReleasableTo=GBR.USA.CAN.AUS.NZL&PolicyIdentifier=GBR"
```

Wait 5 seconds for Lambda to execute, then verify the object remains in the data bucket:

```bash
# Object should still exist in data bucket
aws s3api head-object --bucket "$DATA_BUCKET" --key "reports/intel-report-001.txt"

# Verify tags
aws s3api get-object-tagging --bucket "$DATA_BUCKET" --key "reports/intel-report-001.txt"
```

Check the audit log:
```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"validation_passed"' \
  --limit 5 | jq '.events[].message | fromjson | {event, key, classification}'
```

**Expected outcome:** Object stays in data bucket. Audit log shows `validation_passed` with classification `SECRET`.

#### Test 2: Missing Labels (Negative Test -- Quarantine)

Upload an object with no classification tags:

```bash
echo "Unlabelled content" > /tmp/test-unlabelled.txt

aws s3api put-object \
  --bucket "$DATA_BUCKET" \
  --key "reports/unlabelled-doc.txt" \
  --body /tmp/test-unlabelled.txt
```

Wait 5 seconds, then verify quarantine:

```bash
# Object should have been removed from data bucket
aws s3api head-object --bucket "$DATA_BUCKET" --key "reports/unlabelled-doc.txt" 2>&1
# Expected: "An error occurred (404) when calling the HeadObject operation"

# Object should exist in quarantine bucket
aws s3api head-object --bucket "$QUARANTINE_BUCKET" --key "reports/unlabelled-doc.txt"
```

Check the non-compliance audit:
```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"validation_failed"' \
  --limit 5 | jq '.events[].message | fromjson | {event, key, violations}'
```

**Expected outcome:** Object moved to quarantine. Audit log shows `validation_failed` with violation details. SNS notification sent.

#### Test 3: Invalid Classification Value

Upload with an invalid classification value:

```bash
echo "Badly classified content" > /tmp/test-invalid.txt

aws s3api put-object \
  --bucket "$DATA_BUCKET" \
  --key "reports/invalid-class.txt" \
  --body /tmp/test-invalid.txt \
  --tagging "Classification=CONFIDENTIAL&ReleasableTo=GBR&PolicyIdentifier=GBR"
```

**Expected outcome:** Quarantined. `CONFIDENTIAL` is not in the allowed set (OFFICIAL, SECRET, TOP_SECRET per ACP-240 normalised classifications).

#### Test 4: Compliance Report

Query the audit logs to generate a compliance summary:

```bash
echo "=== COMPLIANT UPLOADS ==="
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"validation_passed"' \
  --start-time $(date -v-1H +%s000) | jq '[.events[].message | fromjson] | length'

echo "=== NON-COMPLIANT (QUARANTINED) ==="
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"validation_failed"' \
  --start-time $(date -v-1H +%s000) | jq '[.events[].message | fromjson] | length'

echo "=== QUARANTINE BUCKET CONTENTS ==="
aws s3 ls "s3://$QUARANTINE_BUCKET/" --recursive
```

### Acceptance Criteria Verification

| AC | Requirement | How to Verify | Pass/Fail |
|----|-------------|---------------|-----------|
| AC1 | Every data store object has Classification, ReleasableTo, PolicyIdentifier | Test 1: compliant upload persists; Test 2: unlabelled upload quarantined | |
| AC2 | Classification restricted to allowed set | Test 3: `CONFIDENTIAL` is quarantined | |
| AC3 | Non-compliant objects quarantined without data loss | Compare file sizes in quarantine vs original | |
| AC4 | Every upload generates audit record | CloudWatch log query returns entries for all tests | |
| AC5 | Labels align to STANAG 4774 | Verify tag schema matches ACP-240 normalised classifications | |

---

## DCS Level 2: Enhanced Labelling and ABAC

### What This Demonstrates

DCS-2 per ACP-240 para 198: enhanced labelling with the full Minimum Essential Metadata (MEM) set, plus ABAC enforcement using Classification and ReleasableTo as core access control attributes (ACP-240 para 247).

**Key ACP-240 requirements demonstrated:**
- Full MEM per ACP-240 Table 0-2 (11 metadata fields)
- ABAC using Classification and ReleasableTo as core policy attributes
- Clearance hierarchy: TOP_SECRET > SECRET > OFFICIAL
- Releasability enforcement (nation codes and COIs)
- Access decision audit trail

### Deploy

```bash
cd architectures/dcs-level-2-aws-enhanced-labeling/terraform

terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

Save the outputs:
```bash
DATA_BUCKET_L2=$(terraform output -raw data_bucket_name)
API_URL=$(terraform output -raw api_gateway_url)
METADATA_TABLE=$(terraform output -raw metadata_table_name)
AUDIT_TABLE=$(terraform output -raw audit_table_name)

echo "Data bucket: $DATA_BUCKET_L2"
echo "API URL: $API_URL"
```

### Seed Test Data

Upload objects at different classification levels with full MEM:

```bash
# SECRET document releasable to FVEY
echo "SECRET intelligence assessment" > /tmp/secret-doc.txt
aws s3api put-object \
  --bucket "$DATA_BUCKET_L2" \
  --key "assessments/threat-assessment-001.txt" \
  --body /tmp/secret-doc.txt \
  --tagging "Classification=SECRET&ReleasableTo=GBR.USA.CAN.AUS.NZL&PolicyIdentifier=GBR"

# Write full MEM to metadata catalog
aws dynamodb put-item --table-name "$METADATA_TABLE" --item '{
  "object_key": {"S": "assessments/threat-assessment-001.txt"},
  "Classification": {"S": "SECRET"},
  "PolicyIdentifier": {"S": "GBR"},
  "CreationDateTime": {"S": "2026-03-16T10:00:00Z"},
  "ReleasableTo": {"S": "GBR.USA.CAN.AUS.NZL"},
  "AdditionalSensitivity": {"S": "NONE"},
  "Administrative": {"S": "NONE"},
  "UniqueIdentifier": {"S": "GBR-THREAT-2026-001"},
  "Creator": {"S": "UK Defence Intelligence"},
  "DateTimeCreated": {"S": "2026-03-16T10:00:00Z"},
  "Publisher": {"S": "Ministry of Defence"},
  "Title": {"S": "Threat Assessment Eastern Europe Q1 2026"}
}'

# OFFICIAL document releasable to NATO
echo "OFFICIAL logistics briefing" > /tmp/official-doc.txt
aws s3api put-object \
  --bucket "$DATA_BUCKET_L2" \
  --key "briefings/logistics-briefing-001.txt" \
  --body /tmp/official-doc.txt \
  --tagging "Classification=OFFICIAL&ReleasableTo=NATO&PolicyIdentifier=NATO"

aws dynamodb put-item --table-name "$METADATA_TABLE" --item '{
  "object_key": {"S": "briefings/logistics-briefing-001.txt"},
  "Classification": {"S": "OFFICIAL"},
  "PolicyIdentifier": {"S": "NATO"},
  "CreationDateTime": {"S": "2026-03-16T11:00:00Z"},
  "ReleasableTo": {"S": "NATO"},
  "AdditionalSensitivity": {"S": "NONE"},
  "Administrative": {"S": "NONE"},
  "UniqueIdentifier": {"S": "NATO-LOG-2026-001"},
  "Creator": {"S": "NATO SHAPE"},
  "DateTimeCreated": {"S": "2026-03-16T11:00:00Z"},
  "Publisher": {"S": "NATO Allied Command Operations"},
  "Title": {"S": "Logistics Briefing March 2026"}
}'

# TOP_SECRET document releasable to GBR only
echo "TOP SECRET UK-only assessment" > /tmp/topsecret-doc.txt
aws s3api put-object \
  --bucket "$DATA_BUCKET_L2" \
  --key "assessments/uk-only-assessment-001.txt" \
  --body /tmp/topsecret-doc.txt \
  --tagging "Classification=TOP_SECRET&ReleasableTo=GBR&PolicyIdentifier=GBR"

aws dynamodb put-item --table-name "$METADATA_TABLE" --item '{
  "object_key": {"S": "assessments/uk-only-assessment-001.txt"},
  "Classification": {"S": "TOP_SECRET"},
  "PolicyIdentifier": {"S": "GBR"},
  "CreationDateTime": {"S": "2026-03-16T12:00:00Z"},
  "ReleasableTo": {"S": "GBR"},
  "AdditionalSensitivity": {"S": "UK EYES ONLY"},
  "Administrative": {"S": "NONE"},
  "UniqueIdentifier": {"S": "GBR-UKEO-2026-001"},
  "Creator": {"S": "UK Defence Intelligence"},
  "DateTimeCreated": {"S": "2026-03-16T12:00:00Z"},
  "Publisher": {"S": "Ministry of Defence"},
  "Title": {"S": "UK Eyes Only Strategic Assessment"}
}'
```

### Demonstrate

#### Test 1: SECRET-Cleared UK Analyst Accesses SECRET Document (ALLOW)

```bash
curl -s -X POST "$API_URL/access" \
  -H "Content-Type: application/json" \
  -d '{
    "object_key": "assessments/threat-assessment-001.txt",
    "persona": "uk-secret-analyst"
  }' | jq '{decision, persona, classification, releasable_to, content_preview}'
```

**Expected:** `decision: ALLOW`. User clearance SECRET >= object classification SECRET, and nationality GBR is in releasability list.

#### Test 2: OFFICIAL-Cleared NATO Analyst Accesses SECRET Document (DENY)

```bash
curl -s -X POST "$API_URL/access" \
  -H "Content-Type: application/json" \
  -d '{
    "object_key": "assessments/threat-assessment-001.txt",
    "persona": "nato-official-analyst"
  }' | jq '{decision, reason}'
```

**Expected:** `decision: DENY`. Reason: insufficient clearance (OFFICIAL < SECRET).

#### Test 3: OFFICIAL-Cleared NATO Analyst Accesses OFFICIAL Document (ALLOW)

```bash
curl -s -X POST "$API_URL/access" \
  -H "Content-Type: application/json" \
  -d '{
    "object_key": "briefings/logistics-briefing-001.txt",
    "persona": "nato-official-analyst"
  }' | jq '{decision, persona, classification, releasable_to}'
```

**Expected:** `decision: ALLOW`. OFFICIAL >= OFFICIAL, and NATO_PARTNER nationality is covered by NATO releasability.

#### Test 4: SECRET-Cleared UK Analyst Accesses TOP_SECRET Document (DENY)

```bash
curl -s -X POST "$API_URL/access" \
  -H "Content-Type: application/json" \
  -d '{
    "object_key": "assessments/uk-only-assessment-001.txt",
    "persona": "uk-secret-analyst"
  }' | jq '{decision, reason}'
```

**Expected:** `decision: DENY`. Reason: insufficient clearance (SECRET < TOP_SECRET).

#### Test 5: TOP_SECRET-Cleared UK Analyst Accesses TOP_SECRET Document (ALLOW)

```bash
curl -s -X POST "$API_URL/access" \
  -H "Content-Type: application/json" \
  -d '{
    "object_key": "assessments/uk-only-assessment-001.txt",
    "persona": "uk-top-secret-analyst"
  }' | jq '{decision, persona, classification}'
```

**Expected:** `decision: ALLOW`. TOP_SECRET >= TOP_SECRET and GBR in releasability.

#### Test 6: Audit Trail Review

```bash
echo "=== ALL ACCESS DECISIONS ==="
aws dynamodb scan --table-name "$AUDIT_TABLE" | \
  jq '.Items[] | {
    timestamp_iso: .timestamp_iso.S,
    persona: .persona.S,
    object_key: .object_key.S,
    decision: .decision.S,
    denial_reason: .denial_reason.S
  }'
```

#### Test 7: MEM Completeness Check

```bash
echo "=== METADATA CATALOG CONTENTS ==="
aws dynamodb scan --table-name "$METADATA_TABLE" | \
  jq '.Items[] | {
    object_key: .object_key.S,
    Classification: .Classification.S,
    ReleasableTo: .ReleasableTo.S,
    Title: .Title.S,
    Creator: .Creator.S,
    UniqueIdentifier: .UniqueIdentifier.S
  }'
```

### Acceptance Criteria Verification

| AC | Requirement | Test | Pass/Fail |
|----|-------------|------|-----------|
| AC1 | Full MEM per ACP-240 Table 0-2 | Test 7: all 11 fields populated in DynamoDB | |
| AC2.a | Access granted when clearance >= classification AND nationality in releasability | Tests 1, 3, 5 | |
| AC2.b | Access denied when clearance < classification | Tests 2, 4 | |
| AC2.c | Clearance hierarchy correct | SECRET denied TOP_SECRET (Test 4), TOP_SECRET can access all | |
| AC3 | Every access attempt audited with full attribution | Test 6: all decisions in DynamoDB with user/object attrs | |
| AC4 | Extended MEM in searchable catalog | Test 7: DynamoDB metadata queryable | |

---

## DCS Level 3: Cryptographic Protection

### What This Demonstrates

DCS-3 per ACP-240 para 199: cryptographic protection providing both confidentiality (encryption) and integrity (metadata signing). Per ACP-240 para 202, data must be transformed into a DCS object (this demo uses KMS envelope encryption as an AWS-native equivalent to demonstrate the concepts).

**Key ACP-240 requirements demonstrated:**
- Per-classification encryption keys (cryptographic separation)
- Envelope encryption pattern (DEK wraps data, KMS KEK wraps DEK)
- ABAC enforcement via KMS key policies using `aws:PrincipalTag/Clearance`
- HMAC signing of metadata for integrity verification
- Cryptographic audit trail via CloudTrail and application logs
- Data protection persists regardless of storage location

### Deploy

```bash
cd architectures/dcs-level-3-aws-cryptographic-protection/terraform

terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

Save the outputs:
```bash
L3_API_URL=$(terraform output -raw api_gateway_url)
L3_BUCKET=$(terraform output -raw data_bucket_name)
L3_AUDIT=$(terraform output -raw audit_table_name)

echo "API URL: $L3_API_URL"
echo "Encrypted data bucket: $L3_BUCKET"
```

### Demonstrate

#### Test 1: Encrypt a SECRET Document

```bash
ENCRYPT_RESULT=$(curl -s -X POST "$L3_API_URL/encrypt" \
  -H "Content-Type: application/json" \
  -d '{
    "plaintext": "This is SECRET intelligence data that must be cryptographically protected per DCS-3.",
    "classification": "SECRET",
    "releasable_to": "GBR.USA.CAN.AUS.NZL",
    "policy_id": "GBR",
    "title": "DCS-3 Test Document"
  }')

echo "$ENCRYPT_RESULT" | jq .
SECRET_KEY=$(echo "$ENCRYPT_RESULT" | jq -r '.object_key')
echo "Encrypted object key: $SECRET_KEY"
```

**Expected:** Returns object key, classification, and confirmation that HMAC signing was applied.

Verify the stored object is encrypted (not readable as plaintext):

```bash
# Download the encrypted object -- it should be ciphertext, not readable
aws s3 cp "s3://$L3_BUCKET/$SECRET_KEY" /tmp/encrypted-object.bin
xxd /tmp/encrypted-object.bin | head -5
echo "---"
echo "File size: $(wc -c < /tmp/encrypted-object.bin) bytes"
echo "The above is ciphertext -- not the original plaintext."
```

#### Test 2: Decrypt as SECRET-Cleared UK Analyst (ALLOW)

```bash
curl -s -X POST "$L3_API_URL/decrypt" \
  -H "Content-Type: application/json" \
  -d "{
    \"object_key\": \"$SECRET_KEY\",
    \"persona\": \"uk-secret-analyst\"
  }" | jq '{decision, persona, classification, plaintext}'
```

**Expected:** `decision: ALLOW`. The original plaintext is returned. KMS key policy allowed decryption because the role's `Clearance=SECRET` tag is in the `dcs-secret-key` allowed set.

#### Test 3: Decrypt as OFFICIAL-Cleared NATO Analyst (DENY -- Cryptographic Enforcement)

```bash
curl -s -X POST "$L3_API_URL/decrypt" \
  -H "Content-Type: application/json" \
  -d "{
    \"object_key\": \"$SECRET_KEY\",
    \"persona\": \"nato-official-analyst\"
  }" | jq '{decision, reason}'
```

**Expected:** `decision: DENY`. Reason: KMS key policy denied access. The OFFICIAL-cleared role cannot use the `dcs-secret-key` because its `Clearance=OFFICIAL` tag is not in the allowed set `["SECRET", "TOP_SECRET"]`. The data was never decrypted -- the consumer never received the DEK.

This is the critical difference from DCS-2: even if someone bypasses IAM policies or S3 bucket policies, the KMS key policy is a separate, independent enforcement layer. Without KMS access, the ciphertext is useless.

#### Test 4: Encrypt and Decrypt at Different Classification Levels

```bash
# Encrypt an OFFICIAL document
OFFICIAL_RESULT=$(curl -s -X POST "$L3_API_URL/encrypt" \
  -H "Content-Type: application/json" \
  -d '{
    "plaintext": "OFFICIAL logistics data.",
    "classification": "OFFICIAL",
    "releasable_to": "NATO",
    "policy_id": "NATO",
    "title": "Logistics Brief"
  }')
OFFICIAL_KEY=$(echo "$OFFICIAL_RESULT" | jq -r '.object_key')

# OFFICIAL analyst CAN decrypt OFFICIAL data
curl -s -X POST "$L3_API_URL/decrypt" \
  -H "Content-Type: application/json" \
  -d "{\"object_key\": \"$OFFICIAL_KEY\", \"persona\": \"nato-official-analyst\"}" | \
  jq '{decision, classification, plaintext}'

# Encrypt a TOP_SECRET document
TS_RESULT=$(curl -s -X POST "$L3_API_URL/encrypt" \
  -H "Content-Type: application/json" \
  -d '{
    "plaintext": "TOP SECRET strategic assessment.",
    "classification": "TOP_SECRET",
    "releasable_to": "GBR",
    "policy_id": "GBR",
    "title": "UK Strategic Assessment"
  }')
TS_KEY=$(echo "$TS_RESULT" | jq -r '.object_key')

# SECRET analyst CANNOT decrypt TOP_SECRET data
curl -s -X POST "$L3_API_URL/decrypt" \
  -H "Content-Type: application/json" \
  -d "{\"object_key\": \"$TS_KEY\", \"persona\": \"uk-secret-analyst\"}" | \
  jq '{decision, reason}'

# TOP_SECRET analyst CAN decrypt TOP_SECRET data
curl -s -X POST "$L3_API_URL/decrypt" \
  -H "Content-Type: application/json" \
  -d "{\"object_key\": \"$TS_KEY\", \"persona\": \"uk-top-secret-analyst\"}" | \
  jq '{decision, classification, plaintext}'
```

#### Test 5: Metadata Integrity Verification (Tampering Detection)

Demonstrate that modifying object tags is detected:

```bash
# Tamper with the classification tag (downgrade from SECRET to OFFICIAL)
aws s3api put-object-tagging \
  --bucket "$L3_BUCKET" \
  --key "$SECRET_KEY" \
  --tagging 'TagSet=[{Key=Classification,Value=OFFICIAL},{Key=ReleasableTo,Value=NATO},{Key=PolicyIdentifier,Value=NATO}]'

# Now try to decrypt -- HMAC check should fail
curl -s -X POST "$L3_API_URL/decrypt" \
  -H "Content-Type: application/json" \
  -d "{
    \"object_key\": \"$SECRET_KEY\",
    \"persona\": \"uk-top-secret-analyst\"
  }" | jq '{error}'
```

**Expected:** HTTP 409 with error "Metadata integrity check failed". The HMAC signature computed over the original metadata no longer matches the tampered tags.

#### Test 6: Cryptographic Audit Trail

```bash
echo "=== CRYPTO OPERATIONS AUDIT ==="
aws dynamodb scan --table-name "$L3_AUDIT" | \
  jq '.Items[] | {
    timestamp_iso: .timestamp_iso.S,
    operation: .operation.S,
    object_key: .object_key.S,
    persona: .persona.S,
    classification: .classification.S,
    outcome: .outcome.S,
    reason: .reason.S
  }'
```

Also check CloudTrail for KMS operations:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=Decrypt \
  --max-results 10 | \
  jq '.Events[] | {EventTime, EventName, Username: .Username, errorCode: (.CloudTrailEvent | fromjson | .errorCode)}'
```

#### Test 7: Data Protection Persists Beyond Storage

Copy the encrypted object to a completely different bucket and show it remains protected:

```bash
# Create a temp bucket
TEMP_BUCKET="dcs-test-copy-$(date +%s)"
aws s3 mb "s3://$TEMP_BUCKET"

# Copy the encrypted object
aws s3 cp "s3://$L3_BUCKET/$SECRET_KEY" "s3://$TEMP_BUCKET/copied-object.enc"

# The copied object is still ciphertext -- cannot be read without KMS
aws s3 cp "s3://$TEMP_BUCKET/copied-object.enc" /tmp/copied-encrypted.bin
xxd /tmp/copied-encrypted.bin | head -3
echo "Data remains encrypted regardless of storage location."

# Clean up
aws s3 rb "s3://$TEMP_BUCKET" --force
```

### Acceptance Criteria Verification

| AC | Requirement | Test | Pass/Fail |
|----|-------------|------|-----------|
| AC1 | Per-classification KMS keys with ABAC key policies | Tests 2, 3, 4: different keys enforce different clearance levels | |
| AC2 | Envelope encryption with wrapped DEK in metadata | Test 1: object stored as ciphertext with metadata | |
| AC3 | HMAC metadata integrity verified on decrypt | Test 5: tag tampering detected | |
| AC4.a | SECRET can decrypt SECRET, not TOP_SECRET | Test 4 | |
| AC4.b | OFFICIAL cannot decrypt SECRET | Test 3: KMS AccessDeniedException | |
| AC5 | All crypto ops in audit trail | Test 6: DynamoDB + CloudTrail entries | |
| AC6 | Protection persists regardless of location | Test 7: copied object still encrypted | |

---

## Full DCS Maturity Demonstration Script

Run all three levels end-to-end to tell the complete DCS story:

```bash
#!/bin/bash
# Full DCS 1-2-3 Demonstration
set -e

echo "=============================================="
echo "  DCS MATURITY LEVELS 1-2-3 DEMONSTRATION"
echo "  Per ACP-240 (March 2024)"
echo "=============================================="

echo ""
echo "--- DCS-1: BASIC LABELLING ---"
echo "Demonstrating: All data must be labelled with"
echo "classification and releasability per STANAG 4774"
echo ""
echo "1. Upload labelled object -> ACCEPTED"
echo "2. Upload unlabelled object -> QUARANTINED"
echo "3. Upload invalid classification -> QUARANTINED"
echo ""

echo "--- DCS-2: ENHANCED LABELLING + ABAC ---"
echo "Demonstrating: Full MEM metadata enables ABAC"
echo "where access requires clearance >= classification"
echo "AND nationality in releasability"
echo ""
echo "4. SECRET analyst accesses SECRET doc -> ALLOW"
echo "5. OFFICIAL analyst accesses SECRET doc -> DENY"
echo "6. TOP_SECRET analyst accesses all levels -> ALLOW"
echo ""

echo "--- DCS-3: CRYPTOGRAPHIC PROTECTION ---"
echo "Demonstrating: Data encrypted with per-classification"
echo "KMS keys. Even if access controls bypassed, data"
echo "remains protected by cryptography"
echo ""
echo "7. Encrypt SECRET doc with dcs-secret-key -> ENCRYPTED"
echo "8. SECRET analyst decrypts -> ALLOW (KMS permits)"
echo "9. OFFICIAL analyst decrypts -> DENY (KMS blocks)"
echo "10. Tamper with classification tag -> INTEGRITY FAILURE"
echo "11. Copy to different bucket -> STILL ENCRYPTED"
echo ""

echo "=============================================="
echo "  KEY TAKEAWAY"
echo "=============================================="
echo ""
echo "DCS-1: You know WHAT your data is (labelled)"
echo "DCS-2: You control WHO can access it (ABAC)"
echo "DCS-3: You ensure it STAYS protected (crypto)"
echo ""
echo "Each level adds defence-in-depth. DCS-3 ensures"
echo "protection persists even if perimeter, network,"
echo "or access control mechanisms are compromised."
```

---

## Teardown

Destroy infrastructure in reverse order:

```bash
# Level 3
cd architectures/dcs-level-3-aws-cryptographic-protection/terraform
terraform destroy -auto-approve

# Level 2
cd ../../dcs-level-2-aws-enhanced-labeling/terraform
terraform destroy -auto-approve

# Level 1
cd ../../dcs-level-1-aws-labeling/terraform
terraform destroy -auto-approve
```

**Warning:** KMS keys have a 7-day deletion window. They will be scheduled for deletion but not immediately removed. This is an AWS safety feature to prevent accidental key loss.

---

## Mapping to ACP-240

| ACP-240 Reference | Requirement | Demo Coverage |
|-------------------|-------------|---------------|
| Para 197 (DCS-1) | Majority of new data labelled / basic labelling | Level 1: S3 tags validated against STANAG 4774 schema |
| Para 198 (DCS-2) | Enhanced labelling with additional metadata | Level 2: Full MEM in DynamoDB catalog |
| Para 199 (DCS-3) | Cryptographic protection (encryption + signing) | Level 3: KMS envelope encryption + HMAC |
| Para 200 | Classification + releasability for DCS-1 | Level 1: Classification, ReleasableTo, PolicyIdentifier tags |
| Para 200 | Additional metadata for DCS-2 | Level 2: Creator, Publisher, Title, DateTimeCreated, etc. |
| Para 200 | Encryption of data + signing of metadata for DCS-3 | Level 3: KMS encrypt + HMAC-SHA256 metadata signing |
| Para 202 | Native file transformed into DCS object for DCS-3 | Level 3: plaintext -> encrypted S3 object with wrapped DEK |
| Para 247 | Classification and ReleasableTo as core ABAC attributes | Levels 2+3: ABAC uses these as primary access control attributes |
| Para 247 | HMAC signing of access control metadata within DCS object | Level 3: HMAC-SHA256 of classification/releasability/policy |
| Table 0-1 | Clearance to normalised classification map | Levels 2+3: TOP_SECRET > SECRET > OFFICIAL hierarchy |
| Table 0-2 | Minimum Essential Metadata | Level 2: all 11 normalised MEM fields in DynamoDB |
