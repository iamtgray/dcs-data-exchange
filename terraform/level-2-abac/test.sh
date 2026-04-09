#!/usr/bin/env bash
# test.sh - Validate DCS Level 2 ABAC infrastructure
#
# Tests the Lambda data service which uses Amazon Verified Permissions
# (Cedar policies) to evaluate ABAC access decisions. The Lambda reads
# from DynamoDB and calls AVP with user/resource attributes.
#
# Prerequisites: terraform apply completed (creates Cognito pools,
# Verified Permissions policy store, DynamoDB with seed data, Lambda).
#
# Usage: ./test.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
REGION="eu-west-2"
FUNCTION_NAME="dcs-level-2-data-service"

echo "Testing: $FUNCTION_NAME"
echo "================================================"

# Invoke the data service Lambda with simulated API Gateway + Cognito claims
invoke_service() {
  local user_id="$1"
  local clearance_level="$2"
  local nationality="$3"
  local saps="$4"
  local data_id="$5"

  local event
  event=$(python3 -c "
import json
print(json.dumps({
    'httpMethod': 'GET',
    'pathParameters': {'dataId': '$data_id'},
    'requestContext': {
        'authorizer': {
            'claims': {
                'sub': '$user_id',
                'custom:clearanceLevel': '$clearance_level',
                'custom:nationality': '$nationality',
                'custom:saps': '$saps',
                'custom:organisation': 'TEST'
            }
        }
    }
}))
")

  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload "$event" \
    --cli-binary-format raw-in-base64-out \
    --no-cli-pager \
    /tmp/dcs-l2-test.json > /dev/null 2>&1
}

run_test() {
  local test_name="$1"
  local expected="$2"  # "allowed" or "denied" or "not_found"
  local user_id="$3"
  local clearance="$4"
  local nationality="$5"
  local saps="$6"
  local data_id="$7"

  invoke_service "$user_id" "$clearance" "$nationality" "$saps" "$data_id"

  local status_code
  status_code=$(python3 -c "
import json
with open('/tmp/dcs-l2-test.json') as f:
    resp = json.load(f)
print(resp.get('statusCode', 0))
" 2>/dev/null || echo "0")

  local result="FAIL"
  local color="$RED"

  if [ "$expected" = "allowed" ] && [ "$status_code" = "200" ]; then
    result="PASS"; color="$GREEN"
  elif [ "$expected" = "denied" ] && [ "$status_code" = "403" ]; then
    result="PASS"; color="$GREEN"
  elif [ "$expected" = "not_found" ] && [ "$status_code" = "404" ]; then
    result="PASS"; color="$GREEN"
  fi

  if [ "$result" = "PASS" ]; then
    PASS=$((PASS + 1))
    echo -e "${color}  PASS${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "${color}  FAIL${NC} $test_name (status=$status_code, expected=$expected)"
  fi
}

echo ""
echo "Standard access (clearance + nationality + SAP)"
echo "------------------------------------------------"

run_test "UK SECRET user reads intel report (GBR releasable)" \
  "allowed" "uk-analyst" "2" "GBR" "WALL" "intel-report-001"

run_test "Polish SECRET user reads intel report (POL releasable)" \
  "allowed" "pol-analyst" "2" "POL" "" "intel-report-001"

run_test "US SECRET user reads intel report (USA releasable)" \
  "allowed" "us-analyst" "2" "USA" "WALL" "intel-report-001"

echo ""
echo "SAP enforcement"
echo "----------------"

run_test "UK user with WALL SAP reads WALL report" \
  "allowed" "uk-analyst" "2" "GBR" "WALL" "wall-report-003"

run_test "Polish user WITHOUT WALL SAP DENIED WALL report" \
  "denied" "pol-analyst" "2" "POL" "" "wall-report-003"

echo ""
echo "Nationality restrictions"
echo "------------------------"

run_test "UK user reads UK-eyes-only data" \
  "allowed" "uk-analyst" "2" "GBR" "" "uk-eyes-only-002"

run_test "Polish user DENIED UK-eyes-only data" \
  "denied" "pol-analyst" "2" "POL" "" "uk-eyes-only-002"

run_test "US user DENIED UK-eyes-only data" \
  "denied" "us-analyst" "2" "USA" "" "uk-eyes-only-002"

echo ""
echo "Clearance level enforcement"
echo "---------------------------"

run_test "Revoked clearance (level 0) DENIED any data" \
  "denied" "revoked-user" "0" "GBR" "" "intel-report-001"

run_test "UNCLASSIFIED user DENIED SECRET data" \
  "denied" "low-clearance" "0" "GBR" "" "intel-report-001"

echo ""
echo "Originator override"
echo "--------------------"

run_test "Polish user reads POL-originated intel (originator access)" \
  "allowed" "pol-analyst" "2" "POL" "" "intel-report-001"

echo ""
echo "Edge cases"
echo "-----------"

run_test "Non-existent data returns 404" \
  "not_found" "uk-analyst" "2" "GBR" "" "does-not-exist"

echo ""
echo "================================================"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
