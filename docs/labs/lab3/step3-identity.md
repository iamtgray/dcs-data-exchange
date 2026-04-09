# Step 3: Configure Identity and Attributes

The KAS needs to know two things about each user: who they are (authentication) and what attributes they have (authorization). Lab 2 already set up Cognito user pools with custom attributes for clearance, nationality, and SAPs. The OpenTDF platform's Claims entity resolution mode reads these directly from the JWT, no extra identity infrastructure needed.

## Verify your Cognito setup

You should already have these from Lab 2:

| Pool | User | Clearance | Nationality | SAPs |
|------|------|-----------|-------------|------|
| `dcs-level2-uk-idp` | uk-analyst-01 | SECRET (level 2) | GBR | WALL |
| `dcs-level2-pol-idp` | pol-analyst-01 | NATO-SECRET (level 2) | POL | (none) |
| `dcs-level2-us-idp` | us-analyst-01 | IL-6 (level 2) | USA | WALL |

If you skipped Lab 2 or cleaned up, go back to [Lab 2 Step 1](../lab2/step1-cognito.md) and create the user pools and users first.

## Get a Cognito token

Make sure your Cognito app client allows the `USER_PASSWORD_AUTH` flow:

1. Go to **Cognito Console** > open `dcs-level2-uk-idp`
2. Go to **App integration** tab > click on `dcs-uk-client`
3. Under **Authentication flows**, ensure `ALLOW_USER_PASSWORD_AUTH` is enabled

Now get a token:

```bash
UK_POOL_ID="YOUR_UK_POOL_ID"
UK_CLIENT_ID="YOUR_UK_CLIENT_ID"
REGION="eu-west-2"

AUTH_RESULT=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $UK_CLIENT_ID \
  --auth-parameters USERNAME=uk-analyst-01,PASSWORD='TempPass1!' \
  --region $REGION)

ACCESS_TOKEN=$(echo $AUTH_RESULT | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['AuthenticationResult']['AccessToken'])")

ID_TOKEN=$(echo $AUTH_RESULT | python3 -c \
  "import sys,json; print(json.load(sys.stdin)['AuthenticationResult']['IdToken'])")
```

!!! tip "First-time login"
    If the user still has a temporary password, use `admin-set-user-password` with `--permanent` to skip the challenge, or sign in through the Cognito hosted UI once.

## Inspect the token claims

This is what the KAS will use to evaluate access:

```bash
echo $ID_TOKEN | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

```json
{
  "sub": "a1b2c3d4-5678-90ab-cdef-EXAMPLE11111",
  "custom:clearance": "SECRET",
  "custom:nationality": "GBR",
  "custom:saps": "WALL",
  "custom:clearanceLevel": "2",
  "cognito:username": "uk-analyst-01",
  "iss": "https://cognito-idp.eu-west-2.amazonaws.com/eu-west-2_aBcDeFgHi",
  "token_use": "id"
}
```

Those `custom:` prefixed claims are the user attributes from Lab 2. The OpenTDF platform in Claims mode extracts these and uses them for access decisions via subject mappings.

## Configure OpenTDF attributes

Set up the attribute namespace. These define what attributes exist and how they're evaluated.

```bash
KAS_IP="YOUR-TASK-PUBLIC-IP"

# The OpenTDF platform uses Connect RPC (POST with Connect-Protocol-Version header)
curl -X POST "http://$KAS_IP:8080/policy.namespaces.NamespaceService/CreateNamespace" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Connect-Protocol-Version: 1" \
  -H "Content-Type: application/json" \
  -d '{"name":"dcs.example.com"}'
```

Then create the attributes under that namespace:

```bash
# Get the namespace ID from the response above
NS_ID="YOUR-NAMESPACE-ID"

# Classification (hierarchy: UNCLASSIFIED < OFFICIAL < SECRET < TOP-SECRET)
curl -X POST "http://$KAS_IP:8080/policy.attributes.AttributesService/CreateAttribute" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Connect-Protocol-Version: 1" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"classification\",\"namespaceId\":\"$NS_ID\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_HIERARCHY\",\"values\":[\"UNCLASSIFIED\",\"OFFICIAL\",\"SECRET\",\"TOP-SECRET\"]}"

# Releasable (anyOf: user must have at least one matching nationality)
curl -X POST "http://$KAS_IP:8080/policy.attributes.AttributesService/CreateAttribute" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Connect-Protocol-Version: 1" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"releasable\",\"namespaceId\":\"$NS_ID\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_ANY_OF\",\"values\":[\"GBR\",\"USA\",\"POL\"]}"

# SAP (allOf: user must have all required SAPs)
curl -X POST "http://$KAS_IP:8080/policy.attributes.AttributesService/CreateAttribute" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Connect-Protocol-Version: 1" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"sap\",\"namespaceId\":\"$NS_ID\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_ALL_OF\",\"values\":[\"WALL\"]}"
```

The `rule` field defines how attributes are evaluated:

- **hierarchy**: User's value must be >= data's value (for classification levels)
- **anyOf**: User must have at least one matching value (for releasability)
- **allOf**: User must have all required values (for SAPs)

## Configure subject mappings

Subject mappings connect JWT claims to attribute entitlements. This is how the Claims ERS maps Cognito's `custom:nationality` claim to the OpenTDF `releasable` attribute.

```bash
# Map custom:nationality = "GBR" to the GBR releasable attribute
curl -X POST "http://$KAS_IP:8080/policy.subjectmapping.SubjectMappingService/CreateSubjectMapping" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -H "Connect-Protocol-Version: 1" \
  -H "Content-Type: application/json" \
  -d '{
    "attributeValueId": "RELEASABLE_GBR_ATTRIBUTE_VALUE_ID",
    "actions": [{"name": "STANDARD_ACTION_DECRYPT"}, {"name": "STANDARD_ACTION_TRANSMIT"}],
    "newSubjectConditionSet": {
      "subjectSets": [{
        "conditionGroups": [{
          "booleanOperator": "CONDITION_BOOLEAN_TYPE_ENUM_AND",
          "conditions": [{
            "subjectExternalSelectorValue": ".custom:nationality",
            "operator": "SUBJECT_MAPPING_OPERATOR_ENUM_IN",
            "subjectExternalValues": ["GBR"]
          }]
        }]
      }]
    }
  }'
```

!!! note "Attribute value IDs"
    When you created the attribute namespaces above, the API returned IDs for each value. Use those IDs in the subject mappings. List them with:

    ```bash
    curl -X POST "http://$KAS_IP:8080/policy.attributes.AttributesService/ListAttributes" \
      -H "Authorization: Bearer $ID_TOKEN" \
      -H "Connect-Protocol-Version: 1" \
      -H "Content-Type: application/json" \
      -d '{}' | python3 -m json.tool
    ```

Repeat for each mapping:

- `custom:nationality` = `"USA"` → releasable/USA
- `custom:nationality` = `"POL"` → releasable/POL
- `custom:clearance` contains `"SECRET"` → classification/SECRET
- `custom:saps` contains `"WALL"` → sap/WALL

## What you've built

```
Cognito User Pools (from Lab 2)
  |
  | Issues OIDC tokens with custom:clearance,
  | custom:nationality, custom:saps claims
  |
  v
OpenTDF Platform (Claims ERS mode)
  |
  | Reads claims from JWT
  | Applies subject mappings
  | Determines user's attribute entitlements
  |
  v
KAS evaluates: do the user's entitlements
satisfy the TDF's embedded policy?
```

The identity infrastructure from Lab 2 carries straight through.

Next: **[Step 4: Encrypt Your First TDF File](step4-encrypt.md)**
