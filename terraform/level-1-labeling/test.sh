#!/usr/bin/env bash
# test.sh - Validate DCS Level 1 Labeling infrastructure
#
# Tests the Lambda authorizer by simulating API Gateway events.
# The authorizer reads IAM user tags and S3 object tags to make
# access decisions based on clearance, nationality, and SAPs.
#
# Prerequisites: terraform apply completed, test S3 objects uploaded
# with DCS tags, IAM users created with DCS attribute tags.
#
# Usage: ./test.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
REGION="eu-west-2"
PROJECT="dcs-level-1"
FUNCTION_NAME="${PROJECT}-authorizer"
BUCKET=$(terraform output -raw data_bucket_name 2>/dev/null)

echo "Testing: $FUNCTION_NAME"
echo "Bucket:  $BUCKET"
echo "================================================"

# Upload test objects with DCS tags if they don't exist
setup_test_data() {
  echo "Setting up test data..."

  aws s3api put-object --bucket "$BUCKET" --key "logistics.txt" \
    --body /dev/stdin --region "$REGION" \
    --tagging "dcs:classification=UNCLASSIFIED&dcs:releasable-to=ALL&dcs:sap=NONE&dcs:originator=USA" \
    <<< "Unclassified logistics report" > /dev/null 2>&1

  aws s3api put-object --bucket "$BUCKET" --key "intel-report.txt" \
    --body /dev/stdin --region "$REGION" \
    --tagging "dcs:classification=SECRET&dcs:releasable-to=GBR&dcs:sap=NONE&dcs:originator=GBR" \
    <<< "SECRET intelligence assessment" > /dev/null 2>&1

  aws s3api put-object --bucket "$BUCKET" --key "wall-report.txt" \
    --body /dev/stdin --region "$REGION" \
    --tagging "dcs:classification=SECRET&dcs:releasable-to=GBR&dcs:sap=WALL&dcs:originator=GBR" \
    <<< "SECRET WALL compartmented report" > /dev/null 2>&1

  echo "Test data ready."
}

# Invoke the authorizer Lambda with a simulated API Gateway event
invoke_authorizer() {
  local username="$1"
  local object_key="$2"

  local event
  event=$(python3 -c "
import json
print(json.dumps({
    'requestContext': {'identity': {'user': '$username'}},
    'pathParameters': {'objectKey': '$object_key'}
}))
")

  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload "$event" \
    --cli-binary-format raw-in-base64-out \
    --no-cli-pager \
    /tmp/dcs-l1-test.json > /dev/null 2>&1

  cat /tmp/dcs-l1-test.json
}

run_test() {
  local test_name="$1"
  local expected="$2"  # "authorized" or "denied"
  local username="$3"
  local object_key="$4"

  local response
  response=$(invoke_authorizer "$username" "$object_key")

  local status_code authorized
  read -r status_code authorized < <(python3 -c "
import json, sys
resp = json.loads('''$response''')
sc = resp.get('statusCode', 0)
body = json.loads(resp.get('body', '{}'))
auth = body.get('authorized', False)
print(sc, str(auth).lower())
" 2>/dev/null || echo "0 error")

  local result="FAIL"
  local color="$RED"

  if [ "$expected" = "authorized" ] && [ "$authorized" = "true" ]; then
    result="PASS"; color="$GREEN"
  elif [ "$expected" = "denied" ] && [ "$authorized" = "false" ]; then
    result="PASS"; color="$GREEN"
  fi

  if [ "$result" = "PASS" ]; then
    PASS=$((PASS + 1))
    echo -e "${color}  PASS${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "${color}  FAIL${NC} $test_name (status=$status_code, authorized=$authorized, expected=$expected)"
  fi
}

setup_test_data

echo ""
echo "Clearance checks"
echo "-----------------"

run_test "UK SECRET user reads UNCLASSIFIED data" \
  "authorized" "${PROJECT}-user-gbr-secret" "logistics.txt"

run_test "UK SECRET user reads SECRET GBR data" \
  "authorized" "${PROJECT}-user-gbr-secret" "intel-report.txt"

run_test "Contractor reads UNCLASSIFIED data" \
  "authorized" "${PROJECT}-user-contractor" "logistics.txt"

run_test "Contractor DENIED SECRET data (clearance too low)" \
  "denied" "${PROJECT}-user-contractor" "intel-report.txt"

echo ""
echo "Nationality checks"
echo "-------------------"

run_test "Polish user DENIED GBR-only SECRET data" \
  "denied" "${PROJECT}-user-pol-ns" "intel-report.txt"

echo ""
echo "SAP checks"
echo "-----------"

run_test "UK SECRET+WALL user reads WALL report" \
  "authorized" "${PROJECT}-user-gbr-secret" "wall-report.txt"

run_test "Polish user DENIED WALL report (no SAP)" \
  "denied" "${PROJECT}-user-pol-ns" "wall-report.txt"

echo ""
echo "================================================"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
