#!/usr/bin/env bash
# test-labs.sh - Validate that deployed DCS labs infrastructure works correctly
#
# Runs the same scenarios from the hands-on labs against the deployed
# Lambda function. Tests Lab 1 (data + labels) and Lab 2 (ABAC).
#
# Usage: ./test-labs.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
FUNCTION_NAME="dcs-lab-data-service"
REGION="eu-west-2"

echo "Testing Lambda: $FUNCTION_NAME in $REGION"
echo "================================================"

run_test() {
  local test_name="$1"
  local expected_allowed="$2"  # "true", "false", or "error"
  local payload="$3"

  # Build the Lambda event: {"body": "<json-string>"}
  local lambda_event
  lambda_event=$(python3 -c "
import json, sys
body = sys.argv[1]
print(json.dumps({'body': body}))
" "$payload")

  # Invoke Lambda, capture the response payload to a file
  aws lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --region "$REGION" \
    --payload "$lambda_event" \
    --cli-binary-format raw-in-base64-out \
    --no-cli-pager \
    /tmp/dcs-test-out.json > /dev/null 2>&1

  # Parse the Lambda response (which has statusCode + body as JSON string)
  local status_code allowed
  read -r status_code allowed < <(python3 -c "
import json, sys
with open('/tmp/dcs-test-out.json') as f:
    resp = json.load(f)
sc = resp.get('statusCode', '')
body_str = resp.get('body', '{}')
try:
    body = json.loads(body_str)
    allowed = str(body.get('allowed', '')).lower()
except:
    allowed = ''
print(sc, allowed)
" 2>/dev/null || echo "0 ")

  local result="FAIL"
  local color="$RED"

  if [ "$expected_allowed" = "error" ]; then
    if [ "$status_code" != "200" ] && [ -n "$status_code" ]; then
      result="PASS"
      color="$GREEN"
    fi
  elif [ "$allowed" = "$expected_allowed" ]; then
    result="PASS"
    color="$GREEN"
  fi

  if [ "$result" = "PASS" ]; then
    PASS=$((PASS + 1))
    echo -e "${color}  PASS${NC} $test_name"
  else
    FAIL=$((FAIL + 1))
    echo -e "${color}  FAIL${NC} $test_name (status=$status_code, allowed=$allowed, expected=$expected_allowed)"
  fi
}

# =========================================================================
# Lab 1: Data exists and has labels
# =========================================================================
echo ""
echo "Lab 1: Data labeling"
echo "--------------------"

run_test \
  "UK analyst reads UNCLASSIFIED logistics report" \
  "true" \
  '{"objectKey":"logistics-report.txt","username":"uk-analyst-01","clearanceLevel":2,"nationality":"GBR","saps":["WALL"]}'

run_test \
  "UK analyst reads SECRET intel report" \
  "true" \
  '{"objectKey":"intel-report.txt","username":"uk-analyst-01","clearanceLevel":2,"nationality":"GBR","saps":["WALL"]}'

run_test \
  "UK analyst reads SECRET+WALL operation report" \
  "true" \
  '{"objectKey":"operation-wall.txt","username":"uk-analyst-01","clearanceLevel":2,"nationality":"GBR","saps":["WALL"]}'

# =========================================================================
# Lab 2: ABAC access control
# =========================================================================
echo ""
echo "Lab 2: ABAC access control"
echo "--------------------------"

run_test \
  "Polish analyst reads intel report (POL is releasable)" \
  "true" \
  '{"objectKey":"intel-report.txt","username":"pol-analyst-01","clearanceLevel":2,"nationality":"POL","saps":[]}'

run_test \
  "Polish analyst reads WALL report (DENIED - missing SAP)" \
  "false" \
  '{"objectKey":"operation-wall.txt","username":"pol-analyst-01","clearanceLevel":2,"nationality":"POL","saps":[]}'

run_test \
  "US analyst reads WALL report (has WALL SAP)" \
  "true" \
  '{"objectKey":"operation-wall.txt","username":"us-analyst-01","clearanceLevel":2,"nationality":"USA","saps":["WALL"]}'

run_test \
  "Revoked user reads logistics (DENIED - clearance=0)" \
  "false" \
  '{"objectKey":"logistics-report.txt","username":"revoked-user","clearanceLevel":0,"nationality":"GBR","saps":[]}'

run_test \
  "Contractor reads SECRET intel (DENIED - clearance too low)" \
  "false" \
  '{"objectKey":"intel-report.txt","username":"contractor","clearanceLevel":0,"nationality":"GBR","saps":[]}'

# =========================================================================
# Edge cases
# =========================================================================
echo ""
echo "Edge cases"
echo "----------"

run_test \
  "Missing objectKey returns error" \
  "error" \
  '{"username":"uk-analyst-01","clearanceLevel":2,"nationality":"GBR","saps":[]}'

run_test \
  "Non-existent object returns error" \
  "error" \
  '{"objectKey":"does-not-exist.txt","username":"uk-analyst-01","clearanceLevel":2,"nationality":"GBR","saps":[]}'

# =========================================================================
# Summary
# =========================================================================
echo ""
echo "================================================"
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"

if [ "$FAIL" -gt 0 ]; then
  echo -e "${RED}SOME TESTS FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}ALL TESTS PASSED${NC}"
  exit 0
fi
