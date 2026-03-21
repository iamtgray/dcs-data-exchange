# Step 3: Create Simulated Users

We need users with different security attributes to test our access control. We'll create IAM users with tags that represent their clearance level, nationality, and special access programs.

!!! note "Why IAM users?"
    In a real DCS system, user attributes would come from an identity provider (Active Directory, Keycloak, etc.). We're using IAM user tags here because they're quick to set up and easy to demonstrate.

## Create three test users

### User 1: UK analyst with SECRET + WALL

1. Open the **IAM Console**: [https://console.aws.amazon.com/iam](https://console.aws.amazon.com/iam)
2. Click **Users** > **Create user**
3. **User name**: `dcs-user-gbr-secret`
4. **Do not** provide console access (we'll use the CLI)
5. Click **Next**, skip the permissions page, click **Next** again
6. Add these **Tags**:

| Key | Value |
|-----|-------|
| `dcs:clearance` | `SECRET` |
| `dcs:nationality` | `GBR` |
| `dcs:saps` | `WALL` |

7. Click **Create user**

### User 2: Polish analyst with NATO SECRET, no SAPs

1. Click **Create user**
2. **User name**: `dcs-user-pol-ns`
3. Tags:

| Key | Value |
|-----|-------|
| `dcs:clearance` | `NATO-SECRET` |
| `dcs:nationality` | `POL` |
| `dcs:saps` | |

4. Click **Create user**

### User 3: Uncleared contractor

1. Click **Create user**
2. **User name**: `dcs-user-contractor`
3. Tags:

| Key | Value |
|-----|-------|
| `dcs:clearance` | `UNCLASSIFIED` |
| `dcs:nationality` | `GBR` |
| `dcs:saps` | |

4. Click **Create user**

## What these users represent

| User | Clearance | Nationality | SAPs | Should be able to read... |
|------|-----------|-------------|------|--------------------------|
| `dcs-user-gbr-secret` | SECRET | UK | WALL | All three files |
| `dcs-user-pol-ns` | NATO-SECRET | Poland | None | logistics-report, intel-report (not operation-wall - no WALL SAP) |
| `dcs-user-contractor` | UNCLASSIFIED | UK | None | Only logistics-report |

This table is our expected outcome. In Step 5, we'll verify that the authorizer produces exactly these results.

## Understanding classification mapping

Notice that the UK user has "SECRET" clearance and the Polish user has "NATO-SECRET" clearance. These are different labels from different national systems, but they represent the same level of trust.

Our authorizer will need a mapping:

```
UNCLASSIFIED    = Level 0
OFFICIAL        = Level 1
NATO-RESTRICTED = Level 1
SECRET          = Level 2
NATO-SECRET     = Level 2
IL-5 / IL-6     = Level 2
TOP-SECRET      = Level 3
```

This mapping is a simplified version of what NATO nations agree on for cross-domain sharing.

Next: **[Step 4: Build the Access Checker](step4-authorizer.md)** - the Lambda that makes access decisions.
