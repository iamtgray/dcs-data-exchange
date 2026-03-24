# Step 1: Set Up Identity Providers

In a real coalition, each nation runs its own identity system. We'll simulate this with three Amazon Cognito User Pools, one for each nation. Each pool will have users with custom attributes for clearance, nationality, and SAPs.

## Create the UK User Pool

1. Go to **Cognito Console**: [https://console.aws.amazon.com/cognito](https://console.aws.amazon.com/cognito)
2. Click **Create user pool**
3. **Sign-in experience**:
    - Provider types: Cognito user pool
    - Sign-in options: User name
4. **Security requirements**:
    - Password policy: Custom - set minimum length to 8, no special requirements (this is a demo)
    - MFA: No MFA
5. **Sign-up experience**: Defaults are fine
6. **Message delivery**: Email with Cognito (default)
7. **Integrate your app**:
    - User pool name: `dcs-level2-uk-idp`
    - App client name: `dcs-uk-client`
    - Client secret: Don't generate a client secret
8. Click **Create user pool**

### Add custom attributes

1. Open the new user pool `dcs-level2-uk-idp`
2. Go to **Sign-up experience** tab
3. Scroll to **Custom attributes** > **Add custom attributes**
4. Add these four:

| Name | Type | Min | Max | Mutable |
|------|------|-----|-----|---------|
| `clearance` | String | 1 | 50 | Yes |
| `nationality` | String | 2 | 5 | No |
| `saps` | String | 0 | 200 | Yes |
| `clearanceLevel` | Number | 0 | 5 | Yes |

### Create a UK test user

1. Go to **Users** tab > **Create user**
2. **User name**: `uk-analyst-01`
3. **Temporary password**: Set a password you'll remember (e.g., `TempPass1!`)
4. Click **Create user**

Now set the custom attributes via CLI (the console doesn't easily set custom attributes at creation):

```bash
aws cognito-idp admin-update-user-attributes \
  --user-pool-id YOUR_UK_POOL_ID \
  --username uk-analyst-01 \
  --user-attributes \
    Name="custom:clearance",Value="SECRET" \
    Name="custom:nationality",Value="GBR" \
    Name="custom:saps",Value="WALL" \
    Name="custom:clearanceLevel",Value="2"
```

!!! tip "Find your User Pool ID"
    It's shown at the top of the user pool page, formatted like `eu-west-2_aBcDeFgHi`.

## Create the Poland User Pool

Repeat the same process:

1. Create user pool: `dcs-level2-pol-idp`
2. App client: `dcs-pol-client`
3. Add the same four custom attributes
4. Create user: `pol-analyst-01`
5. Set attributes:

```bash
aws cognito-idp admin-update-user-attributes \
  --user-pool-id YOUR_POL_POOL_ID \
  --username pol-analyst-01 \
  --user-attributes \
    Name="custom:clearance",Value="NATO-SECRET" \
    Name="custom:nationality",Value="POL" \
    Name="custom:saps",Value="" \
    Name="custom:clearanceLevel",Value="2"
```

## Create the US User Pool

1. Create user pool: `dcs-level2-us-idp`
2. App client: `dcs-us-client`
3. Add the same four custom attributes
4. Create user: `us-analyst-01`
5. Set attributes:

```bash
aws cognito-idp admin-update-user-attributes \
  --user-pool-id YOUR_US_POOL_ID \
  --username us-analyst-01 \
  --user-attributes \
    Name="custom:clearance",Value="IL-6" \
    Name="custom:nationality",Value="USA" \
    Name="custom:saps",Value="WALL" \
    Name="custom:clearanceLevel",Value="2"
```

## What you've built

Three separate identity providers, each representing a nation:

| Pool | User | Clearance | Nationality | SAPs |
|------|------|-----------|-------------|------|
| UK | uk-analyst-01 | SECRET (level 2) | GBR | WALL |
| Poland | pol-analyst-01 | NATO-SECRET (level 2) | POL | none |
| US | us-analyst-01 | IL-6 (level 2) | USA | WALL |

In a production system, these would be real identity providers (Active Directory, Keycloak, etc.) federated into your system via SAML or OIDC. Cognito gives us the same JWT token-based authentication flow.

!!! note "Record your Pool IDs and Client IDs"
    You'll need the User Pool ID and App Client ID for each pool in later steps. Write them down or keep the console tabs open.

Next: **[Step 2: Create the Policy Engine](step2-policies.md)**
