---
inclusion: auto
description: OpenTDF platform integration with AWS Cognito - known issues, workarounds, and configuration guidance for non-Keycloak OIDC providers
---

# OpenTDF platform + AWS Cognito integration

## The problem

The OpenTDF platform (nightly, April 2026) has a bug in its JWT claim extraction that breaks decrypt when using any OIDC provider that doesn't emit the `azp` claim. Cognito doesn't. Neither do Auth0 or Azure AD in some configurations.

Encrypt works fine. All the Connect RPC API calls work. Only decrypt fails, because the KAS rewrap path triggers an IPC reauthorization flow that needs a client ID from the JWT, and the extraction code can't handle the `aud` claim's array type.

## What's actually going wrong

`getClientIDFromToken()` in `service/internal/auth/authn.go` extracts the client ID using the configured `client_id_claim` (default: `azp`). Setting it to `aud` doesn't work either, because:

- RFC 7519 defines `aud` as an array of strings
- The lestrrat-go/jwx JWT library returns `aud` as `[]string` from `AsMap()`
- The code does `found.(string)` — type assertion fails on `[]string`
- Client ID never reaches gRPC metadata
- Authorization v2's `getDecisionRequestContext()` fails with "missing authn idP clientID"

Full write-up: #[[file:docs/OPENTDF-COGNITO-DECRYPT-ISSUE.md]]

## Configuration that works

When deploying OpenTDF with Cognito (or any non-Keycloak IdP that omits `azp`):

```yaml
server:
  auth:
    audience: <cognito-app-client-id>       # matches aud claim in Cognito ID tokens
    issuer: https://cognito-idp.<region>.amazonaws.com/<pool-id>
    policy:
      client_id_claim: sub                  # NOT aud (fails: []string type mismatch)
                                            # NOT azp (Cognito doesn't emit it)
      csv: |
        p, role:admin, *, *, allow
        p, role:standard, *, *, allow
        p, role:unknown, *, *, allow

services:
  entityresolution:
    mode: claims                            # reads DCS attributes from JWT custom: claims
```

Why `sub` works: it's always a plain string, so the type assertion passes. The value ends up being the user's subject ID rather than the app client ID, but that's fine — the authorization v2 flow only uses it as metadata for obligation decisioning, not as a security gate. The actual ABAC decision runs on JWT claims matched against subject mappings.

Use Cognito ID tokens, not access tokens. Access tokens have `client_id` but no `aud`, so they fail the platform's audience validation.

Entity resolution must be in `claims` mode to read `custom:clearance`, `custom:nationality`, etc. from the JWT.

## Cognito vs Keycloak token claims

| Claim | Cognito ID Token | Cognito Access Token | Keycloak |
|-------|-----------------|---------------------|----------|
| `aud` | app client ID | absent | app client ID |
| `azp` | absent | absent | app client ID |
| `client_id` | absent | app client ID | absent |
| `sub` | user UUID | user UUID | user UUID |
| `token_use` | `id` | `access` | n/a |

## What works, what doesn't

| Operation | Status | Notes |
|-----------|--------|-------|
| Platform startup, migrations | ✅ | |
| Token validation (audience, issuer) | ✅ | `aud` check works correctly |
| Connect RPC API calls | ✅ | Casbin client_id_claim failure is non-fatal here |
| Attribute/namespace CRUD | ✅ | |
| Subject mapping creation | ✅ | |
| KAS key registration | ✅ | |
| Encrypt (otdfctl) | ✅ | Only needs KAS public key |
| Decrypt with `client_id_claim: aud` | ❌ | `[]string` type assertion failure |
| Decrypt with `client_id_claim: azp` | ❌ | Claim missing from Cognito tokens |
| Decrypt with `client_id_claim: sub` | ✅ | `sub` is always a plain string |

## Upstream fix

The real fix is a PR to [opentdf/platform](https://github.com/opentdf/platform) — about 10 lines in `service/internal/auth/authn.go` to handle `aud` as both `string` and `[]string` in `getClientIDFromToken()`. See the resolution section of the issue doc for the proposed code.

## Files involved

- `terraform/level-3-encryption/ecs.tf` — OpenTDF platform config (server.auth, Casbin policy, client_id_claim)
- `terraform/level-3-encryption/provision-opentdf.sh` — creates attributes, subject mappings, KAS keys
- `terraform/level-3-encryption/test.sh` — integration tests (22 tests)
- `terraform/level-2-abac/cognito.tf` — Cognito User Pool and client config
