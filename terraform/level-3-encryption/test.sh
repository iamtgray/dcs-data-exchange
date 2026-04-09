#!/usr/bin/env bash
# test.sh - Validate DCS Level 3 Encryption infrastructure and Cognito auth
#
# Tests:
# 1. Infrastructure: KMS key, RDS, ECS cluster/service, S3 bucket
# 2. OpenTDF platform: health endpoint, well-known config
# 3. Cognito auth: authenticate as UK analyst, get ID token
# 4. OpenTDF API with Cognito token: verify the platform accepts it
#
# Prerequisites:
#   - Level 2 deployed (Cognito user pools with test users)
#   - Level 3 deployed with cognito_uk_pool_id and cognito_uk_client_id
#
# Usage: ./test.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASS=0
FAIL=0
REGION="eu-west-2"
PROJECT="dcs-level-3"
export AWS_PAGER=""

echo "Testing Level 3 Encryption: infrastructure + Cognito auth + OpenTDF"
echo "==================================================================="

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

# Read terraform outputs
KMS_KEY_ID=$(terraform output -raw kms_key_id 2>/dev/null)
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
COGNITO_POOL_ID=$(terraform output -raw cognito_uk_pool_id 2>/dev/null)
COGNITO_CLIENT_ID=$(terraform output -raw cognito_uk_client_id 2>/dev/null)

# =========================================================================
# 1. Infrastructure checks
# =========================================================================
echo ""
echo "Infrastructure"
echo "--------------"

key_state=$(aws kms describe-key --key-id "$KMS_KEY_ID" --region "$REGION" \
  --query "KeyMetadata.KeyState" --output text 2>/dev/null || echo "MISSING")
check "KMS key is enabled" "$([ "$key_state" = "Enabled" ] && echo 0 || echo 1)"

key_usage=$(aws kms describe-key --key-id "$KMS_KEY_ID" --region "$REGION" \
  --query "KeyMetadata.KeyUsage" --output text 2>/dev/null || echo "")
check "KMS key is ENCRYPT_DECRYPT" "$([ "$key_usage" = "ENCRYPT_DECRYPT" ] && echo 0 || echo 1)"

db_status=$(aws rds describe-db-instances --db-instance-identifier "${PROJECT}-opentdf" --region "$REGION" \
  --query "DBInstances[0].DBInstanceStatus" --output text 2>/dev/null || echo "MISSING")
check "RDS instance is available" "$([ "$db_status" = "available" ] && echo 0 || echo 1)"

cluster_status=$(aws ecs describe-clusters --clusters "$CLUSTER" --region "$REGION" \
  --query "clusters[0].status" --output text 2>/dev/null || echo "MISSING")
check "ECS cluster is active" "$([ "$cluster_status" = "ACTIVE" ] && echo 0 || echo 1)"

# =========================================================================
# 2. Find the running OpenTDF task and its public IP
# =========================================================================
echo ""
echo "OpenTDF platform"
echo "-----------------"

task_arn=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "${PROJECT}-opentdf" \
  --region "$REGION" --desired-status RUNNING --query "taskArns[0]" --output text 2>/dev/null || echo "None")

PLATFORM_IP=""
if [ "$task_arn" != "None" ] && [ -n "$task_arn" ]; then
  check "ECS task is running" 0

  eni=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$task_arn" --region "$REGION" \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text 2>/dev/null || echo "")
  if [ -n "$eni" ] && [ "$eni" != "None" ]; then
    PLATFORM_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni" --region "$REGION" \
      --query "NetworkInterfaces[0].Association.PublicIp" --output text 2>/dev/null || echo "")
  fi
else
  check "ECS task is running" 1
  echo -e "${RED}  Cannot continue without a running task.${NC}"
  echo ""
  echo "==================================================================="
  TOTAL=$((PASS + FAIL))
  echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
  exit 1
fi

PLATFORM_URL="http://${PLATFORM_IP}:8080"
echo -e "${YELLOW}  INFO${NC} Platform URL: $PLATFORM_URL"

# Health check
health=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${PLATFORM_URL}/healthz" 2>/dev/null || echo "000")
check "OpenTDF /healthz responds 200" "$([ "$health" = "200" ] && echo 0 || echo 1)"

# Well-known config (proves the platform is serving its API)
wellknown=$(curl -s --connect-timeout 5 "${PLATFORM_URL}/.well-known/opentdf-configuration" 2>/dev/null || echo "")
has_kas=$(echo "$wellknown" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'key_access_servers' in str(d) or 'configuration' in str(d) else 'no')" 2>/dev/null || echo "no")
check "OpenTDF well-known config is served" "$([ "$has_kas" = "yes" ] && echo 0 || echo 1)"

# =========================================================================
# 3. Cognito authentication
# =========================================================================
echo ""
echo "Cognito authentication"
echo "----------------------"

# Authenticate as uk-analyst-01 and get an ID token
AUTH_RESULT=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$COGNITO_CLIENT_ID" \
  --auth-parameters USERNAME=uk-analyst-01,PASSWORD='DemoP@ss2025!' \
  --region "$REGION" \
  --output json 2>/dev/null || echo '{"error":"auth_failed"}')

ID_TOKEN=$(echo "$AUTH_RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('AuthenticationResult', {}).get('IdToken', ''))
" 2>/dev/null || echo "")

if [ -n "$ID_TOKEN" ] && [ "$ID_TOKEN" != "" ]; then
  check "Cognito auth returns ID token for uk-analyst-01" 0

  # Decode the token to verify custom claims are present
  claims=$(echo "$ID_TOKEN" | python3 -c "
import sys, base64, json
token = sys.stdin.read().strip()
payload = token.split('.')[1]
# Add padding
payload += '=' * (4 - len(payload) % 4)
decoded = base64.urlsafe_b64decode(payload)
claims = json.loads(decoded)
print(json.dumps({
  'clearance': claims.get('custom:clearance', ''),
  'nationality': claims.get('custom:nationality', ''),
  'saps': claims.get('custom:saps', ''),
  'clearanceLevel': claims.get('custom:clearanceLevel', ''),
  'iss': claims.get('iss', ''),
}))
" 2>/dev/null || echo "{}")

  nationality=$(echo "$claims" | python3 -c "import sys,json; print(json.load(sys.stdin).get('nationality',''))" 2>/dev/null || echo "")
  check "Token contains custom:nationality=GBR" "$([ "$nationality" = "GBR" ] && echo 0 || echo 1)"

  clearance=$(echo "$claims" | python3 -c "import sys,json; print(json.load(sys.stdin).get('clearance',''))" 2>/dev/null || echo "")
  check "Token contains custom:clearance=SECRET" "$([ "$clearance" = "SECRET" ] && echo 0 || echo 1)"

  issuer=$(echo "$claims" | python3 -c "import sys,json; print(json.load(sys.stdin).get('iss',''))" 2>/dev/null || echo "")
  expected_issuer="https://cognito-idp.${REGION}.amazonaws.com/${COGNITO_POOL_ID}"
  check "Token issuer matches Cognito pool" "$([ "$issuer" = "$expected_issuer" ] && echo 0 || echo 1)"
else
  check "Cognito auth returns ID token for uk-analyst-01" 1
  echo -e "${RED}  Auth failed. Check Cognito user pool and client config.${NC}"
fi

# =========================================================================
# 4. OpenTDF API with Cognito token
# =========================================================================
echo ""
echo "OpenTDF API with Cognito token"
echo "-------------------------------"

if [ -n "$ID_TOKEN" ] && [ "$ID_TOKEN" != "" ]; then
  # The platform uses Connect RPC (POST + Connect-Protocol-Version header)
  # Test the policy namespace API with the Cognito token
  ns_response=$(curl -s -w "\n%{http_code}" --connect-timeout 5 \
    -X POST \
    -H "Authorization: Bearer ${ID_TOKEN}" \
    -H "Connect-Protocol-Version: 1" \
    -H "Content-Type: application/json" \
    -d '{}' \
    "${PLATFORM_URL}/policy.namespaces.NamespaceService/ListNamespaces" 2>/dev/null)

  ns_status=$(echo "$ns_response" | tail -1)
  check "Policy API accepts Cognito token (ListNamespaces)" "$([ "$ns_status" = "200" ] && echo 0 || echo 1)"

  # Test the KAS registry API with the Cognito token
  kas_reg_response=$(curl -s -w "\n%{http_code}" --connect-timeout 5 \
    -X POST \
    -H "Authorization: Bearer ${ID_TOKEN}" \
    -H "Connect-Protocol-Version: 1" \
    -H "Content-Type: application/json" \
    -d '{}' \
    "${PLATFORM_URL}/policy.kasregistry.KeyAccessServerRegistryService/ListKeyAccessServers" 2>/dev/null)

  kas_reg_status=$(echo "$kas_reg_response" | tail -1)
  check "KAS Registry API accepts Cognito token (ListKeyAccessServers)" "$([ "$kas_reg_status" = "200" ] && echo 0 || echo 1)"

  # Verify the platform issuer in well-known matches Cognito
  wk_auth=$(curl -s --connect-timeout 5 \
    -H "Authorization: Bearer ${ID_TOKEN}" \
    "${PLATFORM_URL}/.well-known/opentdf-configuration" 2>/dev/null || echo "")
  wk_issuer=$(echo "$wk_auth" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('configuration',{}).get('platform_issuer',''))
" 2>/dev/null || echo "")
  expected_issuer="https://cognito-idp.${REGION}.amazonaws.com/${COGNITO_POOL_ID}"
  check "Platform reports Cognito as its OIDC issuer" "$([ "$wk_issuer" = "$expected_issuer" ] && echo 0 || echo 1)"

  # Verify DCS attributes are provisioned
  echo ""
  echo "DCS attribute provisioning"
  echo "---------------------------"

  attrs_json=$(curl -s -X POST \
    -H "Authorization: Bearer ${ID_TOKEN}" \
    -H "Connect-Protocol-Version: 1" \
    -H "Content-Type: application/json" \
    -d '{}' \
    "${PLATFORM_URL}/policy.attributes.AttributesService/ListAttributes" 2>/dev/null || echo '{}')

  attr_count=$(echo "$attrs_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('attributes',[])))" 2>/dev/null || echo "0")
  check "DCS attributes exist ($attr_count found, need 3)" "$([ "$attr_count" -ge 3 ] && echo 0 || echo 1)"

  has_classification=$(echo "$attrs_json" | python3 -c "import sys,json; attrs=json.load(sys.stdin).get('attributes',[]); print('yes' if any(a['name']=='classification' for a in attrs) else 'no')" 2>/dev/null || echo "no")
  check "classification attribute exists (hierarchy)" "$([ "$has_classification" = "yes" ] && echo 0 || echo 1)"

  has_releasable=$(echo "$attrs_json" | python3 -c "import sys,json; attrs=json.load(sys.stdin).get('attributes',[]); print('yes' if any(a['name']=='releasable' for a in attrs) else 'no')" 2>/dev/null || echo "no")
  check "releasable attribute exists (anyOf)" "$([ "$has_releasable" = "yes" ] && echo 0 || echo 1)"

  has_sap=$(echo "$attrs_json" | python3 -c "import sys,json; attrs=json.load(sys.stdin).get('attributes',[]); print('yes' if any(a['name']=='sap' for a in attrs) else 'no')" 2>/dev/null || echo "no")
  check "sap attribute exists (allOf)" "$([ "$has_sap" = "yes" ] && echo 0 || echo 1)"

  # Verify subject mappings exist
  sm_json=$(curl -s -X POST \
    -H "Authorization: Bearer ${ID_TOKEN}" \
    -H "Connect-Protocol-Version: 1" \
    -H "Content-Type: application/json" \
    -d '{}' \
    "${PLATFORM_URL}/policy.subjectmapping.SubjectMappingService/ListSubjectMappings" 2>/dev/null || echo '{}')

  sm_count=$(echo "$sm_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('subjectMappings',[])))" 2>/dev/null || echo "0")
  check "Subject mappings exist ($sm_count found, need 8)" "$([ "$sm_count" -ge 8 ] && echo 0 || echo 1)"
else
  echo -e "${YELLOW}  SKIP${NC} Skipping API tests - no Cognito token available"
fi

# =========================================================================
# Summary
# =========================================================================
echo ""
echo "==================================================================="
TOTAL=$((PASS + FAIL))
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC} out of ${TOTAL} tests"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
