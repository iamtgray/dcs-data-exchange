# Step 4: Configure Identity and Attributes

The KAS needs to know two things about each user: who they are (authentication) and what attributes they have (authorization). We'll deploy Keycloak as the identity provider and configure OpenTDF's attribute service.

## Option A: Deploy Keycloak on ECS (full setup)

For a complete demo, deploy Keycloak as a second ECS service:

1. Create a new **ECS task definition**:
    - Family: `dcs-level3-keycloak`
    - Image: `quay.io/keycloak/keycloak:latest`
    - Command override: `start-dev` (development mode, no TLS required)
    - Port: 8080
    - Environment variables:
        - `KEYCLOAK_ADMIN` = `admin`
        - `KEYCLOAK_ADMIN_PASSWORD` = choose a password
        - `KC_DB` = `postgres`
        - `KC_DB_URL_HOST` = your RDS endpoint
        - `KC_DB_URL_DATABASE` = `keycloak` (create this DB in RDS first)
        - `KC_DB_USERNAME` = `opentdf`
        - `KC_DB_PASSWORD` = your DB password
    - CPU: 0.5 vCPU, Memory: 1 GB

2. Create an ECS service for Keycloak with a separate target group on port 8080

3. Add an ALB listener rule to route `/auth/*` or a separate subdomain to Keycloak

## Option B: Use Cognito (simpler)

If you completed Lab 2, you can reuse those Cognito user pools. The OpenTDF platform can be configured to accept OIDC tokens from Cognito. This is simpler but less realistic for a NATO demo.

For this guide, we'll describe the Keycloak approach but note where Cognito can substitute.

## Configure Keycloak

Once Keycloak is running, access the admin console at `http://YOUR-ALB-DNS/auth/admin`:

### Create the Coalition realm

1. Click the realm dropdown > **Create Realm**
2. **Realm name**: `coalition`
3. Click **Create**

### Create the SDK client

1. Go to **Clients** > **Create client**
2. **Client ID**: `opentdf-sdk`
3. **Client type**: OpenID Connect
4. **Client authentication**: Off (public client)
5. **Valid redirect URIs**: `*` (demo only)
6. **Web origins**: `*`
7. Click **Save**

### Create test users

Create three users with custom attributes:

**UK Analyst:**

1. Go to **Users** > **Create user**
2. **Username**: `uk-analyst-01`
3. **Email**: `uk-analyst@example.com`
4. Click **Create**
5. Go to **Credentials** tab > **Set password** > enter `demo-password-1` > uncheck Temporary
6. Go to **Attributes** tab > add:
    - `clearance` = `SECRET`
    - `clearanceLevel` = `2`
    - `nationality` = `GBR`
    - `saps` = `WALL`
    - `organisation` = `UK-MOD`

**Polish Analyst:**

- Username: `pol-analyst-01`
- Attributes: clearance=NATO-SECRET, clearanceLevel=2, nationality=POL, saps=(empty), organisation=PL-MON

**US Analyst:**

- Username: `us-analyst-01`
- Attributes: clearance=IL-6, clearanceLevel=2, nationality=USA, saps=WALL, organisation=US-DOD

### Configure token claims

Ensure user attributes are included in OIDC tokens:

1. Go to **Client scopes** > **profile** > **Mappers** > **Add mapper** > **By configuration** > **User Attribute**
2. Add mappers for each attribute:
    - Name: `clearance`, User Attribute: `clearance`, Token Claim Name: `clearance`
    - Name: `nationality`, User Attribute: `nationality`, Token Claim Name: `nationality`
    - Name: `saps`, User Attribute: `saps`, Token Claim Name: `saps`
3. Set all to "Add to ID token: ON" and "Add to access token: ON"

## Configure OpenTDF Attributes

With the OpenTDF platform running, configure the attribute namespace via its API:

```bash
# Get an admin token from Keycloak
TOKEN=$(curl -s -X POST \
  "http://YOUR-ALB-DNS/auth/realms/coalition/protocol/openid-connect/token" \
  -d "grant_type=password" \
  -d "client_id=opentdf-sdk" \
  -d "username=uk-analyst-01" \
  -d "password=demo-password-1" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# Create attribute namespaces
curl -X POST "http://YOUR-ALB-DNS/api/attributes/namespaces" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "https://dcs.example.com/attr/classification",
    "values": ["UNCLASSIFIED", "OFFICIAL", "SECRET", "TOP-SECRET"],
    "rule": "hierarchy"
  }'

curl -X POST "http://YOUR-ALB-DNS/api/attributes/namespaces" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "https://dcs.example.com/attr/releasable",
    "values": ["GBR", "USA", "POL"],
    "rule": "anyOf"
  }'

curl -X POST "http://YOUR-ALB-DNS/api/attributes/namespaces" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "https://dcs.example.com/attr/sap",
    "values": ["WALL"],
    "rule": "allOf"
  }'
```

The `rule` field defines how attributes are evaluated:

- **hierarchy**: User's value must be >= data's value (for classification levels)
- **anyOf**: User must have at least one matching value (for releasability)
- **allOf**: User must have all required values (for SAPs)

## Assign entitlements to users

Map each user to their allowed attributes:

```bash
# UK analyst - SECRET clearance, GBR releasable, WALL SAP
curl -X POST "http://YOUR-ALB-DNS/api/entitlements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "uk-analyst-01",
    "attribute_values": [
      "https://dcs.example.com/attr/classification/value/SECRET",
      "https://dcs.example.com/attr/releasable/value/GBR",
      "https://dcs.example.com/attr/sap/value/WALL"
    ]
  }'

# Polish analyst - SECRET clearance, POL releasable, no SAPs
curl -X POST "http://YOUR-ALB-DNS/api/entitlements" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_id": "pol-analyst-01",
    "attribute_values": [
      "https://dcs.example.com/attr/classification/value/SECRET",
      "https://dcs.example.com/attr/releasable/value/POL"
    ]
  }'
```

Next: **[Step 5: Encrypt Your First TDF File](step5-encrypt.md)**
