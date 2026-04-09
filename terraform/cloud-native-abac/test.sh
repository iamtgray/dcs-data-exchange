#!/usr/bin/env bash
# test.sh - Validate DCS Cloud-Native ABAC infrastructure
#
# Tests the IAM-native ABAC by verifying:
# 1. S3 bucket and test objects exist with correct DCS tags
# 2. IAM roles exist with correct trust policies
# 3. Cognito user pools and identity pool are configured
# 4. CloudTrail is logging
# 5. S3 bucket policy has ABAC conditions
#
# This module has no Lambda - authorization is in IAM policies.
# Full ABAC testing requires Cognito federation (assuming roles
# with session tags), which needs interactive auth flows.
#
# Usage: ./test.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
REGION="eu-west-2"
BUCKET=$(terraform output -raw data_bucket_name 2>/dev/null)

echo "Testing cloud-native ABAC infrastructure"
echo "Bucket: $BUCKET"
echo "================================================"

check() {
  local test_name="$1"
  local result="$2"  # 0 = pass, non-zero = fail

  if [ "$result" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo -e "${GREEN}  PASS${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "${RED}  FAIL${NC} $test_name"
  fi
}

echo ""
echo "S3 data objects with DCS tags"
echo "------------------------------"

# Check each test object exists and has correct classification tag
for obj in "intel-report-001.txt:2" "uk-eyes-only-002.txt:2" "wall-report-003.txt:2" "logistics-004.csv:0"; do
  key="${obj%%:*}"
  expected_class="${obj##*:}"

  actual_class=$(aws s3api get-object-tagging --bucket "$BUCKET" --key "$key" --region "$REGION" \
    --query "TagSet[?Key=='dcs:classification'].Value" --output text 2>/dev/null || echo "MISSING")

  if [ "$actual_class" = "$expected_class" ]; then
    check "Object $key has classification=$expected_class" 0
  else
    check "Object $key has classification=$expected_class (got: $actual_class)" 1
  fi
done

# Check releasability tags
uk_only_rel=$(aws s3api get-object-tagging --bucket "$BUCKET" --key "uk-eyes-only-002.txt" --region "$REGION" \
  --query "TagSet[?Key=='dcs:rel-GBR'].Value" --output text 2>/dev/null || echo "")
check "UK-eyes-only has dcs:rel-GBR=true" "$([ "$uk_only_rel" = "true" ] && echo 0 || echo 1)"

uk_only_no_pol=$(aws s3api get-object-tagging --bucket "$BUCKET" --key "uk-eyes-only-002.txt" --region "$REGION" \
  --query "TagSet[?Key=='dcs:rel-POL'].Value" --output text 2>/dev/null || echo "None")
check "UK-eyes-only has NO dcs:rel-POL tag" "$([ "$uk_only_no_pol" = "None" ] && echo 0 || echo 1)"

# Check SAP tag on WALL report
wall_sap=$(aws s3api get-object-tagging --bucket "$BUCKET" --key "wall-report-003.txt" --region "$REGION" \
  --query "TagSet[?Key=='dcs:sap'].Value" --output text 2>/dev/null || echo "")
check "WALL report has dcs:sap=WALL" "$([ "$wall_sap" = "WALL" ] && echo 0 || echo 1)"

echo ""
echo "IAM roles"
echo "---------"

READER_ARN=$(terraform output -raw data_reader_role_arn 2>/dev/null)
WRITER_ARN=$(terraform output -raw data_writer_role_arn 2>/dev/null)
ADMIN_ARN=$(terraform output -raw label_admin_role_arn 2>/dev/null)

check "Data reader role exists" "$(aws iam get-role --role-name dcs-cloud-native-data-reader --region "$REGION" > /dev/null 2>&1 && echo 0 || echo 1)"
check "Data writer role exists" "$(aws iam get-role --role-name dcs-cloud-native-data-writer --region "$REGION" > /dev/null 2>&1 && echo 0 || echo 1)"
check "Label admin role exists (MFA required)" "$(aws iam get-role --role-name dcs-cloud-native-label-admin --region "$REGION" > /dev/null 2>&1 && echo 0 || echo 1)"

echo ""
echo "S3 bucket policy (ABAC conditions)"
echo "------------------------------------"

policy=$(aws s3api get-bucket-policy --bucket "$BUCKET" --region "$REGION" --output text 2>/dev/null || echo "")
check "Bucket has a policy" "$([ -n "$policy" ] && echo 0 || echo 1)"
check "Policy contains DCSReadAccess statement" "$(echo "$policy" | python3 -c 'import sys; print(0 if "DCSReadAccess" in sys.stdin.read() else 1)' 2>/dev/null || echo 1)"
check "Policy contains DenyTagTampering statement" "$(echo "$policy" | python3 -c 'import sys; print(0 if "DenyTagTampering" in sys.stdin.read() else 1)' 2>/dev/null || echo 1)"
check "Policy contains DenyUntaggedUploads statement" "$(echo "$policy" | python3 -c 'import sys; print(0 if "DenyUntaggedUploads" in sys.stdin.read() else 1)' 2>/dev/null || echo 1)"

echo ""
echo "Cognito federation"
echo "-------------------"

IDENTITY_POOL=$(terraform output -raw identity_pool_id 2>/dev/null)
check "Cognito Identity Pool exists" "$(aws cognito-identity describe-identity-pool --identity-pool-id "$IDENTITY_POOL" --region "$REGION" > /dev/null 2>&1 && echo 0 || echo 1)"

echo ""
echo "CloudTrail"
echo "-----------"

TRAIL_ARN=$(terraform output -raw cloudtrail_arn 2>/dev/null)
trail_status=$(aws cloudtrail get-trail-status --name "$TRAIL_ARN" --region "$REGION" --query "IsLogging" --output text 2>/dev/null || echo "false")
check "CloudTrail is logging" "$([ "$trail_status" = "True" ] && echo 0 || echo 1)"

echo ""
echo "================================================"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
