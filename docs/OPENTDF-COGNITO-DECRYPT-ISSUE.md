# OpenTDF decrypt fails with Cognito: missing client ID in JWT

## The problem

The OpenTDF platform (nightly build, April 2026) can encrypt TDF files using Cognito ID tokens but cannot decrypt them. Encrypt only needs the KAS public key. Decrypt triggers a "rewrap" request where the KAS unwraps the data encryption key, and this rewrap path goes through the platform's authorization v2 service, which rejects the request.

The error chain:

```
otdfctl decrypt -> KAS rewrap -> authorization v2 GetDecision -> IPCMetadataClientInterceptor
-> "missing authn idP clientID"
-> "could not perform access"
```

## Root cause

The platform's internal IPC interceptor (`IPCMetadataClientInterceptor`) extracts the client ID from the JWT token using the `azp` claim. Cognito ID tokens do not have an `azp` claim. Cognito puts the client ID in the `aud` claim instead.

Cognito ID token claims (relevant subset):
```json
{
  "sub": "76b2a234-c001-70ff-6c8e-55cb32622d0d",
  "aud": "a30gedemcrt6vbdf7nbb0cje9",
  "iss": "https://cognito-idp.eu-west-2.amazonaws.com/eu-west-2_LrhyGcjX2",
  "token_use": "id",
  "custom:clearance": "SECRET",
  "custom:nationality": "GBR"
}
```

Note: `aud` contains the Cognito app client ID. There is no `azp` claim.

Cognito access tokens have `client_id` (not `azp` either) and no `aud` claim at all, so they fail the platform's audience validation.

## What we tried

1. Setting `server.auth.policy.client_id_claim: aud` in the OpenTDF config. This affects the Casbin policy layer (role mapping works, API calls succeed with 200) but does NOT affect the IPC interceptor that runs during rewrap.

2. Using Cognito access tokens instead of ID tokens. These have `client_id` but no `aud`, so the platform's audience check (`server.auth.audience`) rejects them as unauthenticated.

3. The `server.auth.policy.client_id_claim` config key is documented at https://opentdf.io/getting-started/configuration under "Casbin Endpoint Authorization". It's described as the claim for extracting the client ID for Casbin role mapping, not for the authorization service's IPC layer.

## What works

Everything except decrypt:
- Platform starts, connects to RDS, runs migrations
- Cognito is the OIDC issuer, platform validates Cognito ID tokens
- Connect RPC API calls (ListNamespaces, ListKeys, CreateKey, SetBaseKey) all work with Cognito tokens
- DCS attributes (classification/hierarchy, releasable/anyOf, sap/allOf) created
- Subject mappings from Cognito JWT claims to attributes created
- KAS key registered with KEY_MODE_CONFIG_ROOT_KEY, base key set
- otdfctl encrypt produces a valid TDF with DCS attributes in the manifest
- 21 out of 22 tests pass

## Architecture context

```
Cognito User Pool (UK IdP)
  |
  | Issues OIDC ID tokens with custom:clearance,
  | custom:nationality, custom:saps, aud=<client_id>
  |
  v
NLB (EIP: stable IP) -> ECS Fargate (OpenTDF platform)
  |                        |
  | server.auth.issuer     | server.auth.audience = <client_id>
  | points at Cognito      | matches aud claim in ID token
  |                        |
  | Claims ERS mode:       | Authorization v2:
  | reads DCS attrs from   | IPCMetadataClientInterceptor
  | JWT custom: claims     | looks for azp claim -> FAILS
  |                        |
  v                        v
  Encrypt works            Decrypt fails at rewrap
  (only needs public key)  (needs authorization decision)
```

## Relevant source code

The IPC interceptor is in the platform source. I couldn't find the exact file, but the log message `IPCMetadataClientInterceptor ipc_server=true error="missing authn idP clientID"` comes from the internal service-to-service auth layer. The authorization v2 service (`namespace=authorization version=v2`) calls `GetDecision` which requires the client ID to contextualize the decision request.

The proto definition for the KAS registry is at:
https://github.com/opentdf/platform/blob/main/service/policy/kasregistry/key_access_server_registry.proto

The platform config reference is at:
https://opentdf.io/getting-started/configuration

The basic key manager (AES-GCM wrapping) is at:
https://github.com/opentdf/platform/blob/main/service/internal/security/basic_manager.go

## Possible solutions to investigate

### 1. Cognito pre-token-generation Lambda
Add a Lambda trigger to the Cognito User Pool that copies the `aud` value into an `azp` claim in the ID token. This is a standard Cognito customization pattern. The platform would then find `azp` where it expects it.

Risk: Cognito may not allow adding `azp` as a custom claim since it's a registered OIDC claim name. Needs testing.

### 2. Platform config for IPC client ID claim
There may be a config option I missed that controls where the IPC interceptor looks for the client ID. The `client_id_claim` in the Casbin policy section only affects Casbin, but there might be a separate setting for the authorization service or the IPC layer. Check the platform source code and config docs more thoroughly.

### 3. Use authorization v1 instead of v2
The error comes from `namespace=authorization version=v2`. The platform might support falling back to authorization v1 which may not require the client ID. Check if there's a config to select the authorization version.

### 4. Disable authorization for rewrap
The Casbin policy already grants `role:unknown` full access. The authorization v2 service might be a separate layer that can be disabled or configured to skip the client ID check. Check if there's a way to bypass it for the rewrap path.

### 5. Use a Cognito resource server with custom scopes
Configure the Cognito User Pool with a resource server and custom scopes. This changes the access token format to include an `aud` claim (the resource server identifier). The platform could then use access tokens with both `aud` and `client_id` claims.

### 6. Register a custom OIDC claim mapping
Some OIDC providers allow claim transformation at the provider level. Cognito's pre-token-generation Lambda (V2 trigger) can modify both ID and access tokens. This is probably the most reliable path.

### 7. Check if the nightly build has a fix
The platform is under active development. The `client_id_claim` config might have been extended to cover the IPC interceptor in a newer commit. Check the platform's GitHub issues and PRs for Cognito compatibility.

## Files involved

- `terraform/level-3-encryption/ecs.tf` - OpenTDF config (server.auth, Casbin policy)
- `terraform/level-3-encryption/provision-opentdf.sh` - Creates attributes, subject mappings, KAS keys
- `terraform/level-3-encryption/test.sh` - 22 tests, 21 pass
- `terraform/level-2-abac/cognito.tf` - Cognito User Pool and client config
- `docs/labs/lab3/step3-identity.md` - Lab docs for identity/attribute config

## Reproduction steps

1. Deploy Level 2: `cd terraform/level-2-abac && terraform apply`
2. Deploy Level 3 with Cognito IDs from Level 2: `cd terraform/level-3-encryption && terraform apply -var='cognito_uk_pool_id=...' -var='cognito_uk_client_id=...' -var='db_password=...'`
3. Wait 3 minutes for ECS task to start
4. Run provisioning: `./provision-opentdf.sh`
5. Run tests: `./test.sh` (21 pass, encrypt passes, decrypt fails)
6. Manual decrypt test:
```bash
export GRPC_ENFORCE_ALPN_ENABLED=false
TOKEN=$(aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH \
  --client-id <CLIENT_ID> --auth-parameters USERNAME=uk-analyst-01,PASSWORD='DemoP@ss2025!' \
  --region eu-west-2 --query 'AuthenticationResult.IdToken' --output text)

echo "test data" | /tmp/otdfctl encrypt --host http://<EIP>:8080 \
  --tls-no-verify --with-access-token "$TOKEN" --tdf-type ztdf \
  --attr "https://dcs.example.com/attr/classification/value/secret" \
  --out /tmp/test.tdf
# This succeeds

/tmp/otdfctl decrypt /tmp/test.tdf --host http://<EIP>:8080 \
  --tls-no-verify --with-access-token "$TOKEN" --tdf-type ztdf \
  --out /tmp/test-dec.txt
# This fails with "could not perform access"
```

## Resolution

### Root cause (detailed)

The bug is in `getClientIDFromToken()` in `service/internal/auth/authn.go`. When `client_id_claim` is set to `aud`, the function calls `tok.AsMap()` and does a string type assertion:

```go
found := dotNotation(claimsMap, clientIDClaim)
clientID, isString := found.(string)
if !isString {
    return "", fmt.Errorf("%w at [%s]", ErrClientIDClaimNotString, clientIDClaim)
}
```

RFC 7519 §4.1.3 defines `aud` as an array of strings. The lestrrat-go/jwx JWT library correctly returns `aud` as `[]string` from `AsMap()`, so `found.(string)` fails. The client ID never makes it into gRPC metadata.

Downstream, authorization v2's `getDecisionRequestContext()` calls `GetClientIDFromContext()`, finds nothing, and returns `ErrMissingClientID` ("missing authn idP clientID"). That propagates up as "could not perform access".

This isn't Cognito-specific. Any OIDC provider that omits `azp` will hit it. `azp` is optional per OpenID Connect Core §2, and Cognito, Auth0, and Azure AD all omit it in various configurations. The platform just assumes Keycloak.

### Workaround applied

Set `client_id_claim: sub` instead of `client_id_claim: aud`.

`sub` is always a plain string in any JWT, so the type assertion passes. The extracted value is the Cognito user's subject identifier rather than the app client ID, but that's fine here. The authorization v2 flow uses this client ID to build a `PolicyEnforcementPoint` context for obligation decisioning — it's metadata, not a security gate. The actual ABAC decision runs on JWT claims matched against subject mappings, which is unaffected. And the Casbin policy grants `role:unknown` full access anyway, so role mapping doesn't matter either.

Config change in `terraform/level-3-encryption/ecs.tf`:

```yaml
server:
  auth:
    policy:
      client_id_claim: sub  # was: aud (fails due to []string type mismatch)
```

### Proper upstream fix

The platform should handle `aud` as both `string` and `[]string` in `getClientIDFromToken()`. About 10 lines:

```go
// In service/internal/auth/authn.go, getClientIDFromToken()
switch v := found.(type) {
case string:
    return v, nil
case []interface{}:
    if len(v) == 1 {
        if s, ok := v[0].(string); ok {
            return s, nil
        }
    }
    return "", fmt.Errorf("%w at [%s]: aud is an array with %d elements", ErrClientIDClaimNotString, clientIDClaim, len(v))
default:
    return "", fmt.Errorf("%w at [%s]", ErrClientIDClaimNotString, clientIDClaim)
}
```

This should be contributed as a PR to [opentdf/platform](https://github.com/opentdf/platform).
