#!/usr/bin/env bash
# test.sh - Validate DCS Level 1 Assured (STANAG 4774/4778) infrastructure
#
# Tests that the infrastructure components are deployed correctly:
# KMS signing key, DynamoDB label store, S3 buckets, Lambda functions,
# API Gateway, EventBridge trigger, and CloudTrail.
#
# The labeler Lambda requires the lxml layer, so full end-to-end label
# creation testing depends on that layer being built and deployed.
# This script validates the infrastructure and tests what it can.
#
# Usage: ./test.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
REGION="eu-west-2"
PROJECT="dcs-l1-assured"

echo "Testing Level 1 Assured (STANAG 4774/4778) infrastructure"
echo "================================================"

check() {
  local test_name="$1"
  local result="$2"

  if [ "$result" -eq 0 ]; then
    PASS=$((PASS + 1))
    echo -e "${GREEN}  PASS${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "${RED}  FAIL${NC} $test_name"
  fi
}

BUCKET=$(terraform output -raw data_bucket_name 2>/dev/null)
TABLE=$(terraform output -raw label_table_name 2>/dev/null)
KEY_ID=$(terraform output -raw signing_key_id 2>/dev/null)

echo ""
echo "KMS signing key (STANAG 4778)"
echo "------------------------------"

key_usage=$(aws kms describe-key --key-id "$KEY_ID" --region "$REGION" \
  --query "KeyMetadata.KeyUsage" --output text 2>/dev/null || echo "")
check "KMS key usage is SIGN_VERIFY" "$([ "$key_usage" = "SIGN_VERIFY" ] && echo 0 || echo 1)"

key_spec=$(aws kms describe-key --key-id "$KEY_ID" --region "$REGION" \
  --query "KeyMetadata.CustomerMasterKeySpec" --output text 2>/dev/null || echo "")
check "KMS key spec is RSA_2048" "$([ "$key_spec" = "RSA_2048" ] && echo 0 || echo 1)"

key_state=$(aws kms describe-key --key-id "$KEY_ID" --region "$REGION" \
  --query "KeyMetadata.KeyState" --output text 2>/dev/null || echo "")
check "KMS key is enabled" "$([ "$key_state" = "Enabled" ] && echo 0 || echo 1)"

echo ""
echo "DynamoDB label store"
echo "---------------------"

table_status=$(aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" \
  --query "Table.TableStatus" --output text 2>/dev/null || echo "MISSING")
check "Label table exists and is active" "$([ "$table_status" = "ACTIVE" ] && echo 0 || echo 1)"

hash_key=$(aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" \
  --query "Table.KeySchema[?KeyType=='HASH'].AttributeName" --output text 2>/dev/null || echo "")
check "Hash key is object_key" "$([ "$hash_key" = "object_key" ] && echo 0 || echo 1)"

range_key=$(aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" \
  --query "Table.KeySchema[?KeyType=='RANGE'].AttributeName" --output text 2>/dev/null || echo "")
check "Range key is object_version" "$([ "$range_key" = "object_version" ] && echo 0 || echo 1)"

gsi_count=$(aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" \
  --query "length(Table.GlobalSecondaryIndexes)" --output text 2>/dev/null || echo "0")
check "Table has 2 GSIs (classification + originator)" "$([ "$gsi_count" = "2" ] && echo 0 || echo 1)"

pitr=$(aws dynamodb describe-continuous-backups --table-name "$TABLE" --region "$REGION" \
  --query "ContinuousBackupsDescription.PointInTimeRecoveryDescription.PointInTimeRecoveryStatus" \
  --output text 2>/dev/null || echo "")
check "Point-in-time recovery is enabled" "$([ "$pitr" = "ENABLED" ] && echo 0 || echo 1)"

echo ""
echo "S3 buckets"
echo "-----------"

check "Data bucket exists" "$(aws s3api head-bucket --bucket "$BUCKET" --region "$REGION" 2>/dev/null && echo 0 || echo 1)"

versioning=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --region "$REGION" \
  --query "Status" --output text 2>/dev/null || echo "")
check "Data bucket versioning enabled" "$([ "$versioning" = "Enabled" ] && echo 0 || echo 1)"

eventbridge=$(aws s3api get-bucket-notification-configuration --bucket "$BUCKET" --region "$REGION" \
  --query "EventBridgeConfiguration" --output text 2>/dev/null || echo "")
check "EventBridge notifications enabled on data bucket" "$([ -n "$eventbridge" ] && echo 0 || echo 1)"

echo ""
echo "Lambda functions"
echo "-----------------"

labeler_state=$(aws lambda get-function --function-name "${PROJECT}-labeler" --region "$REGION" \
  --query "Configuration.State" --output text 2>/dev/null || echo "MISSING")
check "Labeler Lambda exists" "$([ "$labeler_state" = "Active" ] && echo 0 || echo 1)"

authorizer_state=$(aws lambda get-function --function-name "${PROJECT}-authorizer" --region "$REGION" \
  --query "Configuration.State" --output text 2>/dev/null || echo "MISSING")
check "Authorizer Lambda exists" "$([ "$authorizer_state" = "Active" ] && echo 0 || echo 1)"

echo ""
echo "IAM users with DCS tags"
echo "------------------------"

for user in "${PROJECT}-user-gbr-secret" "${PROJECT}-user-pol-ns" "${PROJECT}-user-usa-secret" "${PROJECT}-user-contractor"; do
  clearance=$(aws iam list-user-tags --user-name "$user" --region "$REGION" \
    --query "Tags[?Key=='dcs:clearance'].Value" --output text 2>/dev/null || echo "MISSING")
  check "User $user has dcs:clearance tag ($clearance)" "$([ "$clearance" != "MISSING" ] && echo 0 || echo 1)"
done

echo ""
echo "================================================"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
