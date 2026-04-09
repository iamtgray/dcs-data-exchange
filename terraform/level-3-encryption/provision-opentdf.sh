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

# Find the platform
CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
PLATFORM_IP=$(terraform output -raw platform_ip 2>/dev/null)
KAS="http://${PLATFORM_IP}:8080"

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
echo "5. Registering KAS with public keys..."

KAS_RSA_PEM=$(terraform output -raw kas_rsa_public_key_pem 2>/dev/null)
KAS_EC_PEM=$(terraform output -raw kas_ec_public_key_pem 2>/dev/null)

# Register or get the KAS server
KAS_REG=$(rpc "policy.kasregistry.KeyAccessServerRegistryService/CreateKeyAccessServer" \
  "{\"uri\":\"${KAS}\",\"name\":\"local-kas\"}")
if echo "$KAS_REG" | grep -q '"keyAccessServer"'; then
  KAS_SERVER_ID=$(echo "$KAS_REG" | python3 -c "import sys,json; print(json.load(sys.stdin)['keyAccessServer']['id'])")
  echo "   KAS registered: $KAS_SERVER_ID"
else
  echo "   KAS exists, fetching ID..."
  KAS_SERVER_ID=$(rpc "policy.kasregistry.KeyAccessServerRegistryService/ListKeyAccessServers" '{}' | \
    python3 -c "import sys,json; servers=json.load(sys.stdin).get('keyAccessServers',[]); print(servers[0]['id'] if servers else '')")
  echo "   KAS ID: $KAS_SERVER_ID"
fi

echo ""
echo "6. Creating KAS keys..."

KAS_RSA_PEM=$(terraform output -raw kas_rsa_public_key_pem 2>/dev/null)
KAS_RSA_PRIVATE=$(terraform output -raw kas_rsa_private_key_pem 2>/dev/null)
ROOT_KEY_HEX="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

# Wrap the private key with the root key and create the API request
python3 -c "
import json, base64, os
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

root_key = bytes.fromhex('$ROOT_KEY_HEX')
rsa_pub_pem = '''$KAS_RSA_PEM'''.strip()
rsa_priv_pem = '''$KAS_RSA_PRIVATE'''.strip()

# Wrap private key with AES-256-GCM
aesgcm = AESGCM(root_key)
nonce = os.urandom(12)
wrapped = aesgcm.encrypt(nonce, rsa_priv_pem.encode(), None)
# Format: nonce + ciphertext (base64 encoded)
wrapped_b64 = base64.b64encode(nonce + wrapped).decode()

pub_b64 = base64.b64encode(rsa_pub_pem.encode()).decode()

body = json.dumps({
    'kasId': '$KAS_SERVER_ID',
    'keyId': 'r1',
    'keyAlgorithm': 1,
    'keyMode': 1,
    'publicKeyCtx': {'pem': pub_b64},
    'privateKeyCtx': {'keyId': 'config', 'wrappedKey': wrapped_b64},
    'legacy': True
})
with open('/tmp/kas_key_req.json', 'w') as f:
    f.write(body)
print('OK')
" 2>/dev/null

if [ -f /tmp/kas_key_req.json ]; then
  RSA_KEY_RESULT=$(rpc "policy.kasregistry.KeyAccessServerRegistryService/CreateKey" "$(cat /tmp/kas_key_req.json)")
  if echo "$RSA_KEY_RESULT" | grep -q '"kasKey"'; then
    RSA_KEY_UUID=$(echo "$RSA_KEY_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['kasKey']['key']['id'])" 2>/dev/null)
    echo "   RSA key created: $RSA_KEY_UUID"
  elif echo "$RSA_KEY_RESULT" | grep -q 'already_exists'; then
    echo "   RSA key already exists"
    RSA_KEY_UUID=$(rpc "policy.kasregistry.KeyAccessServerRegistryService/ListKeys" '{}' | \
      python3 -c "import sys,json; keys=json.load(sys.stdin).get('kasKeys',[]); print(next((k['key']['id'] for k in keys if k['key'].get('keyId')=='r1'),''))" 2>/dev/null)
  else
    echo "   WARN RSA key: $(echo "$RSA_KEY_RESULT" | head -c 200)"
  fi
else
  echo "   WARN: Python cryptography module not available, skipping key wrapping"
  echo "   Install with: pip install cryptography"
fi

echo ""
echo "7. Setting base key..."

# Set the RSA key as the base/default key
if [ -n "${RSA_KEY_UUID:-}" ]; then
  BASE_RESULT=$(rpc "policy.kasregistry.KeyAccessServerRegistryService/SetBaseKey" \
    "{\"id\":\"$RSA_KEY_UUID\"}")
  if echo "$BASE_RESULT" | grep -q '"newBaseKey"'; then
    echo "   Base key set to RSA key"
  else
    echo "   WARN base key: $(echo "$BASE_RESULT" | head -c 200)"
  fi
else
  echo "   Skipping (no RSA key UUID available)"
fi

echo ""
echo "Done. The platform is provisioned with DCS attributes and subject mappings."
echo "You can now encrypt/decrypt TDF files using the OpenTDF CLI."
