#!/usr/bin/env bash
# provision-opentdf.sh - Configure OpenTDF with DCS attributes and subject mappings
#
# Creates the attribute namespaces, values, and subject mappings that
# connect Cognito JWT claims to OpenTDF policy attributes. Run this
# after terraform apply once the platform is healthy.
#
# Usage: ./provision-opentdf.sh

set -euo pipefail
export AWS_PAGER=""

REGION="eu-west-2"
COGNITO_POOL_ID=$(terraform output -raw cognito_uk_pool_id 2>/dev/null)
COGNITO_CLIENT_ID=$(terraform output -raw cognito_uk_client_id 2>/dev/null)

# Find the platform IP
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --region "$REGION" \
  --desired-status RUNNING --query "taskArns[0]" --output text)
ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)
KAS_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region "$REGION" \
  --query "NetworkInterfaces[0].Association.PublicIp" --output text)
KAS="http://${KAS_IP}:8080"

echo "Platform: $KAS"
echo "Cognito:  $COGNITO_POOL_ID / $COGNITO_CLIENT_ID"

# Get a fresh Cognito ID token
get_token() {
  aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id "$COGNITO_CLIENT_ID" \
    --auth-parameters USERNAME=uk-analyst-01,PASSWORD='DemoP@ss2025!' \
    --region "$REGION" \
    --query 'AuthenticationResult.IdToken' --output text
}

TOKEN=$(get_token)

# Helper: POST to Connect RPC endpoint
rpc() {
  local endpoint="$1"
  local body="$2"
  curl -s -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Connect-Protocol-Version: 1" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${KAS}/${endpoint}" 2>/dev/null
}

echo ""
echo "1. Creating namespace..."
NS_RESULT=$(rpc "policy.namespaces.NamespaceService/CreateNamespace" '{"name":"dcs.example.com"}' || echo '{"code":"already_exists"}')
if echo "$NS_RESULT" | grep -q "already_exists"; then
  echo "   Namespace already exists, fetching ID..."
  NS_ID=$(rpc "policy.namespaces.NamespaceService/ListNamespaces" '{}' | \
    python3 -c "import sys,json; nss=json.load(sys.stdin).get('namespaces',[]); print(next((n['id'] for n in nss if n['name']=='dcs.example.com'),''))")
else
  NS_ID=$(echo "$NS_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['namespace']['id'])")
fi
echo "   Namespace ID: $NS_ID"

echo ""
echo "2. Creating attributes..."

# Classification (hierarchy: UNCLASSIFIED < OFFICIAL < SECRET < TOP-SECRET)
echo "   classification (hierarchy)..."
CLASS_RESULT=$(rpc "policy.attributes.AttributesService/CreateAttribute" \
  "{\"name\":\"classification\",\"namespaceId\":\"$NS_ID\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_HIERARCHY\",\"values\":[\"UNCLASSIFIED\",\"OFFICIAL\",\"SECRET\",\"TOP-SECRET\"]}" \
  || echo '{"code":"already_exists"}')

# Releasable (anyOf: user must have at least one matching nationality)
echo "   releasable (anyOf)..."
REL_RESULT=$(rpc "policy.attributes.AttributesService/CreateAttribute" \
  "{\"name\":\"releasable\",\"namespaceId\":\"$NS_ID\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_ANY_OF\",\"values\":[\"GBR\",\"USA\",\"POL\"]}" \
  || echo '{"code":"already_exists"}')

# SAP (allOf: user must have all required SAPs)
echo "   sap (allOf)..."
SAP_RESULT=$(rpc "policy.attributes.AttributesService/CreateAttribute" \
  "{\"name\":\"sap\",\"namespaceId\":\"$NS_ID\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_ALL_OF\",\"values\":[\"WALL\"]}" \
  || echo '{"code":"already_exists"}')

echo ""
echo "3. Fetching attribute value IDs..."

# List all attributes to get value IDs for subject mappings
ATTRS=$(rpc "policy.attributes.AttributesService/ListAttributes" "{\"namespaceId\":\"$NS_ID\"}")

python3 -c "
import json, sys

attrs = json.loads('''$ATTRS''').get('attributes', [])
value_map = {}
for attr in attrs:
    name = attr.get('name', '')
    for val in attr.get('values', []):
        fqn = f'{name}/{val[\"value\"]}'
        value_map[fqn] = val['id']
        print(f'   {fqn} -> {val[\"id\"]}')

# Write value map for subject mapping step
with open('/tmp/opentdf_values.json', 'w') as f:
    json.dump(value_map, f)
"

echo ""
echo "4. Creating subject mappings (Cognito claims -> attributes)..."

# Read value map
create_mapping() {
  local value_id="$1"
  local claim="$2"
  local operator="$3"
  local match_value="$4"
  local desc="$5"

  local body
  body=$(python3 -c "
import json
print(json.dumps({
    'attributeValueId': '$value_id',
    'actions': [{'name': 'STANDARD_ACTION_DECRYPT'}, {'name': 'STANDARD_ACTION_TRANSMIT'}],
    'newSubjectConditionSet': {
        'subjectSets': [{
            'conditionGroups': [{
                'booleanOperator': 'CONDITION_BOOLEAN_TYPE_ENUM_AND',
                'conditions': [{
                    'subjectExternalSelectorValue': '.$claim',
                    'operator': '$operator',
                    'subjectExternalValues': ['$match_value']
                }]
            }]
        }]
    }
}))
")

  result=$(rpc "policy.subjectmapping.SubjectMappingService/CreateSubjectMapping" "$body")
  if echo "$result" | grep -q '"subjectMapping"'; then
    echo "   OK: $desc"
  elif echo "$result" | grep -q 'already_exists'; then
    echo "   EXISTS: $desc"
  else
    echo "   WARN: $desc - $(echo "$result" | head -c 200)"
  fi
}

# Get value IDs from the map
get_value_id() {
  python3 -c "
import json
with open('/tmp/opentdf_values.json') as f:
    m = json.load(f)
key = '$1'.lower()
print(m.get(key, 'NOT_FOUND'))
"
}

# Nationality -> releasable
for nation in GBR USA POL; do
  VID=$(get_value_id "releasable/$nation")
  create_mapping "$VID" "custom:nationality" "SUBJECT_MAPPING_OPERATOR_ENUM_IN" "$nation" "nationality=$nation -> releasable/$nation"
done

# Clearance -> classification
for level in UNCLASSIFIED OFFICIAL SECRET TOP-SECRET; do
  VID=$(get_value_id "classification/$level")
  create_mapping "$VID" "custom:clearance" "SUBJECT_MAPPING_OPERATOR_ENUM_IN" "$level" "clearance=$level -> classification/$level"
done

# SAP -> sap
VID=$(get_value_id "sap/WALL")
create_mapping "$VID" "custom:saps" "SUBJECT_MAPPING_OPERATOR_ENUM_IN" "WALL" "saps=WALL -> sap/WALL"

echo ""
echo "5. Registering KAS..."

# Register the in-process KAS so the public key endpoint works
KAS_REG=$(rpc "policy.kasregistry.KeyAccessServerRegistryService/CreateKeyAccessServer" \
  "{\"uri\":\"http://${KAS_IP}:8080\",\"name\":\"local-kas\"}" \
  || echo '{"code":"already_exists"}')
if echo "$KAS_REG" | grep -q '"keyAccessServer"'; then
  echo "   KAS registered"
else
  echo "   KAS registration: $(echo "$KAS_REG" | head -c 100)"
fi

echo ""
echo "Done. The platform is provisioned with DCS attributes and subject mappings."
echo "You can now encrypt/decrypt TDF files using the OpenTDF CLI."
