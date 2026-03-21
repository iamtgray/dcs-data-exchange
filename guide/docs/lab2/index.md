# Lab 2: Access Control (DCS Level 2)

## What you'll build

In this lab, you'll create a system where:

1. Three identity providers (one per nation) manage user attributes
2. A dedicated policy engine (Amazon Verified Permissions) evaluates access rules written in Cedar
3. Data items in DynamoDB carry security labels as attributes
4. A Lambda service ties it all together - checking the policy engine before returning data

This demonstrates **DCS Level 2** - access control driven by a proper policy engine rather than hard-coded logic.

## What's different from Lab 1?

| Aspect | Lab 1 (Level 1) | Lab 2 (Level 2) |
|--------|-----------------|-----------------|
| User identity | IAM user tags | Cognito user pools with JWT tokens |
| Access logic | Hard-coded in Lambda | Declarative Cedar policies in Verified Permissions |
| Policy changes | Requires code change + deploy | Update policy in console, instant effect |
| Data store | S3 with object tags | DynamoDB with label attributes |
| Multiple orgs | Single set of IAM users | Separate Cognito pools per nation |

## What you'll learn

- How **ABAC** (Attribute-Based Access Control) works with a real policy engine
- How **Cedar policies** express complex rules declaratively
- How to **federate identity** across multiple organizations
- How **dynamic policy updates** affect existing data without re-labeling
- Why this is still not enough (setting you up for Level 3)

## Architecture

```
 UK Cognito Pool    PL Cognito Pool    US Cognito Pool
 (UK users +        (PL users +        (US users +
  attributes)        attributes)        attributes)
       |                  |                  |
       +--------+---------+---------+--------+
                |                   |
                v                   v
          API Gateway         Amazon Verified
        (validates JWT)       Permissions (AVP)
                |             [Cedar policies]
                v                   ^
          Lambda Service            |
          - extracts user attrs     |
          - gets data labels -------+--- evaluates
          - calls AVP                    user attrs
          - returns data or 403          vs data labels
                |
                v
            DynamoDB
          (labeled data)
```

## Before you start

- AWS Console access with admin permissions
- Same region as Lab 1 (eu-west-2 recommended)
- About 45 minutes

Let's go. **[Step 1: Set Up Identity Providers](step1-cognito.md)**
