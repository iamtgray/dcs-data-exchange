# Architecture: Cloud-native DCS with AWS IAM ABAC

## Purpose

This architecture implements **DCS Level 1 (Labeling) and Level 2 (Access Control)** using AWS-native IAM primitives instead of custom application-layer enforcement. The IAM evaluation engine itself becomes the Policy Decision Point, eliminating the need for Lambda authorizers, Amazon Verified Permissions, or custom policy engines.

The key insight: AWS IAM already supports Attribute-Based Access Control (ABAC) via principal tags, session tags, and resource tag conditions. Combined with S3 object tagging for labels, STS session policies for dynamic scoping, and organizational policies (SCPs/RCPs) for guardrails, you get a complete DCS Level 2 implementation with no custom code in the authorization path.

After building this, you'll understand:
- How IAM ABAC replaces custom policy engines for DCS access control
- How STS session tags propagate user attributes through the AWS authorization chain
- How S3 tag-based conditions enforce label-aware access at the API level
- How SCPs and RCPs provide organizational guardrails for label integrity
- Where cloud-native ABAC is sufficient and where you still need application-layer logic
- How this compares to the Lambda/Verified Permissions approach

## Architecture overview

```
+------------------------------------------------------------------------+
|                        AWS Organization                                 |
|                                                                         |
|  +------------------------------------------------------------------+  |
|  |  Management Account                                               |  |
|  |                                                                    |  |
|  |  Service Control Policies (SCPs):                                  |  |
|  |  - Deny S3 PutObject without classification tags                   |  |
|  |  - Deny S3 DeleteObjectTagging on dcs:* tags                       |  |
|  |  - Deny STS AssumeRole without required session tags               |  |
|  |                                                                    |  |
|  |  Resource Control Policies (RCPs):                                 |  |
|  |  - Deny access to dcs-data bucket from untagged principals         |  |
|  |  - Require TLS for all S3 operations                               |  |
|  +------------------------------------------------------------------+  |
|                                                                         |
|  +------------------------------------------------------------------+  |
|  |  "Coalition Data" Account                                          |  |
|  |                                                                    |  |
|  |  +------------------------------------------------------------+  |  |
|  |  |  S3 Data Bucket (dcs-data)                                  |  |  |
|  |  |                                                              |  |  |
|  |  |  Bucket Policy:                                              |  |  |
|  |  |  - Allow GetObject ONLY when:                                |  |  |
|  |  |    s3:ExistingObjectTag/dcs:classification                   |  |  |
|  |  |      matches ${aws:PrincipalTag/dcs:clearance}               |  |  |
|  |  |    AND s3:ExistingObjectTag/dcs:releasable-to                |  |  |
|  |  |      contains ${aws:PrincipalTag/dcs:nationality}            |  |  |
|  |  |  - Allow PutObject ONLY with required dcs:* tags             |  |  |
|  |  |                                                              |  |  |
|  |  |  +---------------+ +---------------+ +------------------+   |  |  |
|  |  |  | intel-001.pdf | | sitrep-042    | | logistics.csv    |   |  |  |
|  |  |  | Tags:         | | Tags:         | | Tags:            |   |  |  |
|  |  |  |  class: 2     | |  class: 2     | |  class: 0        |   |  |  |
|  |  |  |  rel: GBR,USA | |  rel: GBR,USA | |  rel: ALL        |   |  |  |
|  |  |  |  sap: WALL   | |  sap: NONE    | |  sap: NONE       |   |  |  |
|  |  |  |  orig: GBR   | |  orig: POL    | |  orig: USA       |   |  |  |
|  |  |  +---------------+ +---------------+ +------------------+   |  |  |
|  |  +------------------------------------------------------------+  |  |
|  |                                                                    |  |
|  |  +------------------------------------------------------------+  |  |
|  |  |  IAM Roles (one per access pattern)                         |  |  |
|  |  |                                                              |  |  |
|  |  |  dcs-data-reader:                                            |  |  |
|  |  |    Trust: Cognito identity pool / external IdP               |  |  |
|  |  |    Policy: Allow s3:GetObject on dcs-data/*                  |  |  |
|  |  |      Condition: tag-based ABAC (see below)                   |  |  |
|  |  |                                                              |  |  |
|  |  |  dcs-data-writer:                                            |  |  |
|  |  |    Trust: Cognito identity pool / external IdP               |  |  |
|  |  |    Policy: Allow s3:PutObject + s3:PutObjectTagging          |  |  |
|  |  |      Condition: must include dcs:* tags                      |  |  |
|  |  +------------------------------------------------------------+  |  |
|  |                                                                    |  |
|  |  +------------------------------------------------------------+  |  |
|  |  |  CloudTrail                                                  |  |  |
|  |  |  - Logs all S3 data events (GetObject, PutObject)            |  |  |
|  |  |  - Logs STS AssumeRole with session tags                     |  |  |
|  |  |  - Logs IAM authorization failures (Access Denied)           |  |  |
|  |  |  - Immutable trail in separate audit bucket                  |  |  |
|  |  +------------------------------------------------------------+  |  |
|  +------------------------------------------------------------------+  |
|                                                                         |
|  +------------------------------------------------------------------+  |
|  |  Identity Accounts (one per nation)                                |  |
|  |                                                                    |  |
|  |  +------------------+ +------------------+ +------------------+   |  |
|  |  | "UK" Account     | | "Poland" Account | | "US" Account     |   |  |
|  |  |                  | |                  | |                  |   |  |
|  |  | Cognito Pool     | | Cognito Pool     | | Cognito Pool     |   |  |
|  |  | or SAML IdP      | | or SAML IdP      | | or SAML IdP      |   |  |
|  |  |                  | |                  | |                  |   |  |
|  |  | Users federate   | | Users federate   | | Users federate   |   |  |
|  |  | via STS with     | | via STS with     | | via STS with     |   |  |
|  |  | session tags:    | | session tags:    | | session tags:    |   |  |
|  |  |  clearance: 2    | |  clearance: 2    | |  clearance: 2    |   |  |
|  |  |  nationality:GBR | |  nationality:POL | |  nationality:USA |   |  |
|  |  |  sap: WALL       | |  sap: (none)     | |  sap: WALL       |   |  |
|  |  +------------------+ +------------------+ +------------------+   |  |
|  +------------------------------------------------------------------+  |
+------------------------------------------------------------------------+
```

## How it achieves DCS without custom code
The critical difference from the other architectures: there is no Lambda authorizer, no Verified Permissions policy store, and no custom policy evaluation logic. The AWS IAM engine evaluates every access request against tag-based conditions natively.

| DCS Concept | Cloud-Native Implementation |
|---|---|
| **Security labels** | S3 object tags (`dcs:classification`, `dcs:releasable-to`, `dcs:sap`, `dcs:originator`) |
| **User attributes** | STS session tags set during federation (`dcs:clearance`, `dcs:nationality`, `dcs:sap`) |
| **Policy Decision Point** | IAM policy evaluation engine (S3 bucket policy + IAM role policy conditions) |
| **ABAC enforcement** | IAM condition keys: `s3:ExistingObjectTag/*` vs `aws:PrincipalTag/*` |
| **Label integrity guardrails** | SCPs deny tag deletion/modification; RCPs deny untagged access |
| **Cross-org federation** | STS AssumeRole with session tags from national IdPs |
| **Audit trail** | CloudTrail S3 data events + STS events |

## Components

### 1. S3 Object Tags as DCS Labels

Every object in the data bucket carries its security label as S3 tags. Tags use numeric classification levels to enable IAM `NumericLessThanEquals` conditions for hierarchy comparison.

**Tag schema:**

| Tag Key | Example Values | Description |
|---|---|---|
| `dcs:classification` | `0`, `1`, `2`, `3` | Numeric classification level (see mapping below) |
| `dcs:classification-name` | `UNCLASSIFIED`, `SECRET` | Human-readable classification (informational) |
| `dcs:releasable-to` | `GBR`, `USA`, `POL` | One tag per releasable nation (see encoding below) |
| `dcs:sap` | `WALL`, `NONE` | Special Access Program requirement |
| `dcs:originator` | `GBR`, `POL`, `USA` | Originating nation |
| `dcs:labeled-at` | `2026-03-21T10:00:00Z` | When label was applied |

**Classification level mapping:**

| Level | Value | NATO Equivalent | UK Equivalent | US Equivalent |
|---|---|---|---|---|
| UNCLASSIFIED | `0` | NATO UNCLASSIFIED | OFFICIAL | UNCLASSIFIED |
| RESTRICTED | `1` | NATO RESTRICTED | — | — |
| SECRET | `2` | NATO SECRET | SECRET | SECRET (IL-6) |
| TOP SECRET | `3` | COSMIC TOP SECRET | TOP SECRET | TOP SECRET |

**Encoding releasability in S3 tags:**

S3 tags are key-value pairs (max 10 per object). To support IAM `StringEquals` conditions against `aws:PrincipalTag/dcs:nationality`, we use a pattern where each releasable nation gets its own tag:

```
dcs:rel-GBR = "true"
dcs:rel-USA = "true"
dcs:rel-POL = "true"
```

This allows the bucket policy to check:

```json
"Condition": {
  "StringEquals": {
    "s3:ExistingObjectTag/dcs:rel-${aws:PrincipalTag/dcs:nationality}": "true"
  }
}
```

This is a key technique: IAM policy variables inside condition keys let you dynamically construct the tag name to check based on the caller's nationality. If a Polish user calls GetObject, IAM checks `s3:ExistingObjectTag/dcs:rel-POL` = `"true"`. If that tag doesn't exist on the object, access is denied.

**Tag budget:** With this encoding, a typical object uses 5-8 of the 10 available S3 tags (classification, classification-name, sap, originator, labeled-at, plus one rel-* tag per releasable nation). Objects releasable to more than ~5 nations may hit the 10-tag limit. For broadly releasable data, use `dcs:rel-ALL = "true"` as a wildcard and handle it in the policy.

### 2. STS Session Tags (User Attributes)

When users authenticate through their national IdP and federate into the Coalition Data account, STS session tags carry their DCS attributes. These tags become `aws:PrincipalTag/*` values available in all IAM policy evaluations for that session.

**Session tags set during AssumeRoleWithSAML or AssumeRoleWithWebIdentity:**

| Tag Key | Example | Source |
|---|---|---|
| `dcs:clearance` | `2` | Mapped from national clearance (SECRET → 2) |
| `dcs:nationality` | `GBR` | From IdP assertion |
| `dcs:sap` | `WALL` | From IdP assertion (comma-separated if multiple) |
| `dcs:organisation` | `UK-MOD` | From IdP assertion |

**How session tags flow:**

```
User authenticates with national IdP (Cognito / SAML)
    ↓
IdP assertion includes: clearance=SECRET, nationality=GBR, sap=WALL
    ↓
STS AssumeRoleWithSAML / AssumeRoleWithWebIdentity
    Maps SAML attributes to session tags:
      dcs:clearance = "2"
      dcs:nationality = "GBR"
      dcs:sap = "WALL"
    ↓
Temporary credentials issued with tags embedded
    ↓
Every AWS API call carries these tags as aws:PrincipalTag/*
    ↓
IAM evaluates: does aws:PrincipalTag/dcs:clearance >= s3:ExistingObjectTag/dcs:classification?
```

**Trust policy on the data-reader role** (requires session tags):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "cognito-identity.amazonaws.com:aud": "eu-west-2:*"
        },
        "ForAllValues:StringLike": {
          "sts:TransitiveTagKeys": ["dcs:*"]
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::saml-provider/NationalIdP"
      },
      "Action": "sts:AssumeRoleWithSAML",
      "Condition": {
        "StringEquals": {
          "SAML:aud": "https://signin.aws.amazon.com/saml"
        }
      }
    }
  ]
}
```

### 3. S3 Bucket Policy (The Policy Decision Point)

This is the core of the architecture. The S3 bucket policy implements DCS ABAC using IAM condition keys. No Lambda, no custom code -- IAM evaluates these conditions on every S3 API call.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DCSReadAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::role/dcs-data-reader"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "NumericLessThanEquals": {
          "s3:ExistingObjectTag/dcs:classification": "${aws:PrincipalTag/dcs:clearance}"
        },
        "StringEquals": {
          "s3:ExistingObjectTag/dcs:rel-${aws:PrincipalTag/dcs:nationality}": "true"
        }
      }
    },
    {
      "Sid": "DCSOriginatorOverride",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::role/dcs-data-reader"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "StringEquals": {
          "s3:ExistingObjectTag/dcs:originator": "${aws:PrincipalTag/dcs:nationality}"
        }
      }
    },
    {
      "Sid": "DCSWriteRequireLabels",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::role/dcs-data-writer"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "StringLike": {
          "s3:RequestObjectTag/dcs:classification": "*"
        },
        "NumericLessThanEquals": {
          "s3:RequestObjectTag/dcs:classification": "${aws:PrincipalTag/dcs:clearance}"
        }
      }
    },
    {
      "Sid": "DenyUntaggedUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "Null": {
          "s3:RequestObjectTag/dcs:classification": "true"
        }
      }
    },
    {
      "Sid": "DenyTagTampering",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:DeleteObjectTagging",
        "s3:PutObjectTagging"
      ],
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": "arn:aws:iam::role/dcs-label-admin"
        }
      }
    }
  ]
}
```

**How the policy statements work together:**

1. `DCSReadAccess`: The main ABAC rule. Allows GetObject only when the caller's clearance level (numeric) is >= the object's classification level AND the object has a `dcs:rel-<nationality>` tag set to `"true"` matching the caller's nationality. Both conditions must be true (AND logic).

2. `DCSOriginatorOverride`: Allows the originating nation to always access their own data, regardless of other restrictions. This is a separate Allow statement, so it works as an OR with the main rule.

3. `DCSWriteRequireLabels`: Writers must include classification tags, and can only classify data at or below their own clearance level (prevents a SECRET-cleared user from labeling something TOP SECRET).

4. `DenyUntaggedUploads`: Explicit deny prevents any upload without classification tags. This fires before any Allow, ensuring every object is labeled.

5. `DenyTagTampering`: Prevents anyone except the label admin role from modifying or deleting tags after upload. This is a critical label integrity control.

**SAP handling:**

SAP enforcement is trickier in pure IAM because you need to check "user has SAP X AND object requires SAP X, OR object requires no SAP." This requires an additional policy statement:

```json
{
  "Sid": "DenySAPMismatch",
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::dcs-data/*",
  "Condition": {
    "StringNotEquals": {
      "s3:ExistingObjectTag/dcs:sap": "NONE"
    },
    "StringNotEquals": {
      "s3:ExistingObjectTag/dcs:sap": "${aws:PrincipalTag/dcs:sap}"
    }
  }
}
```

This denies access when the object's SAP is not "NONE" (i.e., a SAP is required) AND the user's SAP tag doesn't match. The double-negative logic is necessary because IAM doesn't have an "if-then" construct. Note: this handles single-SAP objects. Multi-SAP requirements need the per-nation tag encoding pattern (e.g., `dcs:sap-WALL = "true"`).

### 4. Service Control Policies (Organizational Guardrails)

SCPs applied at the AWS Organization level prevent circumvention of DCS controls. These are deny-only guardrails that no IAM policy in member accounts can override.

**SCP: Enforce labeling on all S3 uploads**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnlabeledS3Uploads",
      "Effect": "Deny",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "Null": {
          "s3:RequestObjectTag/dcs:classification": "true"
        }
      }
    }
  ]
}
```

**SCP: Prevent label tampering**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLabelDeletion",
      "Effect": "Deny",
      "Action": [
        "s3:DeleteObjectTagging",
        "s3:PutObjectTagging"
      ],
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:role/dcs-label-admin"
        }
      }
    }
  ]
}
```

**SCP: Require session tags for federation**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyFederationWithoutTags",
      "Effect": "Deny",
      "Action": [
        "sts:AssumeRoleWithSAML",
        "sts:AssumeRoleWithWebIdentity"
      ],
      "Resource": "arn:aws:iam::*:role/dcs-data-*",
      "Condition": {
        "Null": {
          "aws:RequestTag/dcs:clearance": "true"
        }
      }
    }
  ]
}
```

These SCPs ensure that even if someone misconfigures an IAM policy in a member account, the DCS controls cannot be bypassed. The label-admin role is the only principal that can modify tags, and it should be tightly controlled (break-glass only, with MFA and approval workflows).

### 5. Resource Control Policies (Resource-Side Guardrails)

RCPs complement SCPs by enforcing conditions on the resource side. While SCPs restrict what principals can do, RCPs restrict who can access resources.

**RCP: Deny access from untagged principals**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUntaggedPrincipalAccess",
      "Effect": "Deny",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::dcs-data/*",
      "Condition": {
        "Null": {
          "aws:PrincipalTag/dcs:clearance": "true"
        }
      }
    }
  ]
}
```

This ensures that even service roles, automation accounts, or cross-account access attempts are denied unless the calling principal carries DCS session tags. It's a safety net: if someone creates a new IAM role and forgets to set up ABAC tags, they get denied by default.

### 6. S3 Access Grants (optional -- simplified ABAC)

For organizations using IAM Identity Center, S3 Access Grants provide a managed ABAC layer without writing IAM policies directly.

**How it works:**

1. Create an S3 Access Grants instance linked to IAM Identity Center
2. Define grants that map directory attributes to S3 locations:
   - "Users with `nationality=GBR` can access `s3://dcs-data/gbr-releasable/*`"
   - "Users with `clearance >= SECRET` can access `s3://dcs-data/secret/*`"
3. Users request temporary S3 credentials via the Access Grants endpoint
4. Credentials are scoped to only the S3 prefixes their attributes allow

**Limitations for DCS:**
- Access Grants work on S3 prefixes, not object tags. This means data must be organized by classification/releasability in the key structure (e.g., `secret/gbr-usa/intel-001.pdf`) rather than using tags for ABAC.
- Less flexible than tag-based ABAC for objects with complex releasability.
- Good for simpler classification schemes where prefix-based organization is acceptable.

**When to use:** Access Grants are a good fit when your data naturally organizes into classification/releasability prefixes and you're already using IAM Identity Center. For full tag-based ABAC, use the bucket policy approach.

### 7. CloudTrail Audit

CloudTrail captures the complete audit trail with no additional configuration beyond enabling S3 data events:

**What's logged automatically:**

| Event | What it tells you |
|---|---|
| `s3:GetObject` (success) | Who accessed what data, with their session tags visible in the `userIdentity` block |
| `s3:GetObject` (AccessDenied) | Who was denied, which condition failed (visible in CloudTrail error code) |
| `sts:AssumeRoleWithSAML` | Who federated in, what session tags were set, from which IdP |
| `s3:PutObject` | Who uploaded data, what tags were applied |
| `s3:PutObjectTagging` (denied) | Attempted label tampering, blocked by SCP |

**Audit advantage over Lambda-based approach:** In the Lambda authorizer architecture, you need custom logging in the Lambda to capture why a decision was made. With IAM ABAC, CloudTrail natively logs the principal tags, the resource, and the outcome. The "why" is implicit: if access was denied and the user has `dcs:clearance=1` while the object has `dcs:classification=2`, the reason is clear from the logged attributes.

**Audit limitation:** CloudTrail doesn't log which specific IAM condition caused a deny. You see "Access Denied" but not "failed because clearance < classification" vs "failed because nationality not in releasable-to." For detailed decision tracing, you'd need to add CloudTrail Lake queries or a post-hoc analysis Lambda that correlates principal tags with object tags on denied events.

## Scenarios

### Scenario A: Standard access grant (clearance + nationality)

```
Polish analyst (clearance=2, nationality=POL) → GetObject intel-report-001
  Object tags: dcs:classification=2, dcs:rel-POL=true, dcs:sap=NONE

IAM evaluates bucket policy:
  1. NumericLessThanEquals: 2 <= 2 ✓ (clearance >= classification)
  2. StringEquals: dcs:rel-POL = "true" ✓ (nationality in releasable-to)
  3. SAP deny rule: sap=NONE, so deny condition doesn't match ✓

Result: ACCESS GRANTED (200 OK, object returned)
```

### Scenario B: Access denied -- nationality

```
Polish analyst (clearance=2, nationality=POL) → GetObject uk-eyes-only-002
  Object tags: dcs:classification=2, dcs:rel-GBR=true (no dcs:rel-POL tag)

IAM evaluates bucket policy:
  1. NumericLessThanEquals: 2 <= 2 ✓
  2. StringEquals: dcs:rel-POL = "true" ✗ (tag doesn't exist on object)
  DCSReadAccess: DENY (condition not met)

  Check DCSOriginatorOverride:
  3. StringEquals: dcs:originator = POL? Object has dcs:originator=GBR ✗
  DCSOriginatorOverride: DENY

  No Allow matched.
Result: ACCESS DENIED (403)
```

### Scenario C: Access denied -- clearance too low

```
Contractor (clearance=0, nationality=USA) → GetObject intel-report-001
  Object tags: dcs:classification=2, dcs:rel-USA=true

IAM evaluates:
  1. NumericLessThanEquals: 2 <= 0 ✗ (classification 2 > clearance 0)
  DCSReadAccess: DENY

Result: ACCESS DENIED (403)
```

### Scenario D: Originator override

```
Polish analyst (clearance=1, nationality=POL) → GetObject polish-report-005
  Object tags: dcs:classification=2, dcs:rel-GBR=true, dcs:originator=POL

IAM evaluates DCSReadAccess:
  1. NumericLessThanEquals: 2 <= 1 ✗ (clearance too low)
  DCSReadAccess: DENY

IAM evaluates DCSOriginatorOverride:
  2. StringEquals: dcs:originator (POL) = aws:PrincipalTag/dcs:nationality (POL) ✓
  DCSOriginatorOverride: ALLOW

Result: ACCESS GRANTED (originator always has access to their own data)
```

### Scenario E: Label tampering blocked

```
Malicious user → PutObjectTagging intel-report-001 (tries to change classification to 0)

IAM evaluates DenyTagTampering:
  1. aws:PrincipalArn != dcs-label-admin ✓ (deny condition matches)

Result: ACCESS DENIED (403)
SCP also denies independently (defense in depth)
CloudTrail logs the attempt
```

### Scenario F: Upload without labels blocked

```
User → PutObject new-report.pdf (no dcs:classification tag)

IAM evaluates DenyUntaggedUploads:
  1. Null check: s3:RequestObjectTag/dcs:classification is null ✓ (deny condition matches)

Result: ACCESS DENIED (403)
SCP also denies independently
```

## Comparison with other architectures
| Aspect | Basic Level 1 (Lambda) | Level 2 (Verified Permissions) | Cloud-Native ABAC (this) |
|---|---|---|---|
| **Policy engine** | Custom Lambda code | Amazon Verified Permissions (Cedar) | IAM evaluation engine |
| **Custom code in auth path** | Yes (Lambda authorizer) | Yes (Lambda calls AVP) | No |
| **Policy language** | JavaScript/Python in Lambda | Cedar | IAM policy JSON |
| **Classification hierarchy** | Custom comparison logic | Cedar numeric comparison | `NumericLessThanEquals` condition |
| **Policy expressiveness** | Unlimited (it's code) | High (Cedar is powerful) | Medium (IAM conditions) |
| **Decision audit** | Custom CloudWatch logging | AVP decision logs (detailed) | CloudTrail (principal + resource, no decision trace) |
| **Latency** | Lambda cold start + execution | Lambda + AVP API call | Zero additional latency (IAM inline) |
| **Cost** | Lambda invocations | Lambda + AVP per-request | No additional cost (IAM is free) |
| **Complex boolean logic** | Unlimited | High (AND, OR, NOT, unless) | Limited (multiple statements, double-negation) |
| **Dynamic policy updates** | Redeploy Lambda | Update Cedar policies (instant) | Update IAM/bucket policies (near-instant) |
| **Multi-SAP support** | Easy (code logic) | Easy (Cedar set operations) | Requires tag encoding pattern |
| **Tag limit impact** | None (labels in DynamoDB) | None (labels in DynamoDB) | 10 S3 tags per object |

### When to use which

**Use Cloud-Native ABAC when:**
- Classification scheme is relatively simple (3-5 levels, <5 releasable nations per object)
- You want zero custom code in the authorization path
- Latency matters (no Lambda cold starts)
- Cost matters (no per-request charges)
- You're already using IAM ABAC patterns elsewhere
- The team is comfortable with IAM policy conditions

**Use Verified Permissions (Cedar) when:**
- You need complex policy logic (exceptions, temporal rules, delegation)
- You need detailed decision audit trails (why was access denied?)
- Classification schemes are complex (many SAPs, compound categories)
- You need policy simulation/testing before deployment
- Multiple applications need the same policy engine (not just S3)

**Use Lambda authorizer when:**
- You need to call external systems during authorization
- Policy logic requires data lookups beyond tags
- You're integrating with non-AWS systems
- You need custom response bodies on deny (not just 403)

## Limitations and honest trade-offs

### What this architecture cannot do

1. **No classification hierarchy in a single condition.** IAM's `NumericLessThanEquals` works for numeric levels, but only because we encode classifications as numbers. If your classification scheme isn't a strict linear hierarchy (e.g., compartmented classifications that don't nest), IAM conditions can't express it.

2. **No "why was I denied?" in CloudTrail.** When IAM denies a request, CloudTrail logs `AccessDenied` but doesn't say which condition failed. For compliance regimes that require detailed decision justification, you need Verified Permissions or a post-hoc analysis layer.

3. **S3 tag limit (10 per object).** With the per-nation releasability encoding (`dcs:rel-GBR`, `dcs:rel-USA`, etc.), you consume one tag per releasable nation plus ~4 for other metadata. Objects releasable to more than ~5-6 nations will hit the limit. Workarounds:
   - Use `dcs:rel-ALL = "true"` for broadly releasable data
   - Use S3 prefix-based organization instead of tags for releasability
   - Accept that this architecture works best for data with limited releasability lists

4. **No assured labeling (STANAG 4778).** S3 tags are not cryptographically bound to data. Anyone with the `dcs-label-admin` role can change labels without detection. The SCPs and bucket policy deny rules provide strong guardrails, but they're not cryptographic assurance. For assured Level 1, you still need the KMS signing approach from the assured architecture.

5. **Single-SAP only (without encoding workaround).** The SAP deny rule handles objects requiring a single SAP. Objects requiring multiple SAPs need the same per-tag encoding pattern as releasability (`dcs:sap-WALL=true`, `dcs:sap-COBALT=true`), which further consumes the tag budget.

6. **No policy simulation.** Cedar (Verified Permissions) lets you test "would user X be able to access resource Y?" without making the actual request. IAM has the `iam:SimulateCustomPolicy` API, but it doesn't support S3 object tag conditions in simulation. You have to test with real requests.

7. **IAM policy size limits.** S3 bucket policies are limited to 20KB. For very complex ABAC rules with many statements, you may hit this limit. IAM role policies have a 10KB limit per inline policy (but you can attach up to 10 managed policies).

### What this architecture does well

1. **Zero additional latency.** IAM evaluation happens inline with every S3 API call. No Lambda cold starts, no network hops to a policy engine. Access decisions are as fast as S3 itself.

2. **Zero additional cost.** IAM policy evaluation is free. No Lambda invocations, no Verified Permissions per-request charges. The only costs are S3 storage, CloudTrail, and STS (all of which you'd have anyway).

3. **No custom code to maintain.** The entire authorization logic is declarative IAM policy JSON. No Lambda functions to deploy, patch, monitor, or debug. No application code that could have bugs in the authorization path.

4. **Defense in depth.** SCPs, RCPs, bucket policies, and IAM role policies all enforce DCS rules independently. An attacker would need to compromise multiple layers simultaneously.

5. **Native AWS integration.** Works with any AWS service that reads from S3 (Athena, EMR, Glue, SageMaker) without modification. Any service that assumes a role with session tags and calls S3 gets ABAC enforcement automatically.

6. **Scales to zero.** No always-on compute (no Lambda, no ECS). The architecture is entirely serverless and event-driven at the IAM layer.

## Extending to DCS Level 3

This architecture covers Level 1 (labeling via S3 tags) and Level 2 (access control via IAM ABAC). For Level 3 (encryption), cloud-native options are more limited:

**Partial Level 3 with SSE-KMS:**
- Use S3 SSE-KMS with a KMS key policy that enforces ABAC conditions on `kms:Decrypt`
- Data is encrypted at rest, and only principals with matching session tags can decrypt
- Limitation: S3 handles encryption/decryption transparently, so it's not true client-side encryption. A privileged insider (within your organization or the cloud provider) could theoretically access plaintext during processing. Note that some AWS services offer zero-operator access guarantees, but S3 is not one of them at the time of writing.

**True Level 3 still requires OpenTDF/KAS:**
- For data that must be encrypted before reaching AWS, you need client-side encryption with a KAS
- The KAS can use IAM ABAC internally (checking session tags before releasing DEKs), combining this architecture's approach with Level 3 encryption
- See the Level 3 architecture for the full OpenTDF approach

**Hybrid approach:**
- Use this cloud-native ABAC architecture for Level 1 + 2
- Add SSE-KMS with ABAC key policies for "Level 2.5" (encryption at rest with attribute-based key access)
- Reserve full Level 3 (OpenTDF) for data that crosses organizational boundaries or requires protection independent of AWS infrastructure

## What you'll learn

After building this architecture, you'll understand:

1. **IAM is already a policy engine.** You don't always need a separate PDP. For tag-based ABAC with straightforward rules, IAM conditions are sufficient and simpler.

2. **Session tags are the bridge.** The key mechanism is STS session tags that carry user attributes from the IdP into every AWS API call. This is how identity attributes flow through the AWS authorization chain.

3. **Encoding matters.** How you encode labels in S3 tags determines what IAM conditions you can write. The per-nation tag pattern (`dcs:rel-GBR`) enables dynamic policy variable substitution that a comma-separated value (`releasable-to: GBR,USA`) would not.

4. **Guardrails complement ABAC.** SCPs and RCPs provide organizational-level enforcement that individual IAM policies can't override. They're the "belt and suspenders" for label integrity.

5. **Simplicity has limits.** IAM ABAC works well for the 80% case. Complex classification schemes, detailed audit requirements, or multi-attribute boolean logic may push you toward Verified Permissions. Know when to graduate.

6. **Cloud-native doesn't mean less secure.** This architecture has fewer moving parts than the Lambda/AVP approach, which means fewer things that can break or be misconfigured. Simplicity is a security property.

## Estimated cost

This architecture adds essentially zero cost beyond baseline AWS services:

| Component | Monthly Cost | Notes |
|---|---|---|
| S3 storage | ~$1-5 | Depends on data volume |
| CloudTrail (S3 data events) | ~$2-10 | $0.10 per 100,000 events |
| STS AssumeRole | Free | No charge for STS calls |
| IAM policy evaluation | Free | No charge |
| Cognito (if used for IdP) | Free tier | Up to 50,000 MAU |

Total: ~$3-15/month for demonstration, significantly less than the Lambda/AVP approach.

## Terraform overview

See `terraform.md` for the complete infrastructure-as-code including:
- S3 bucket with tag-based bucket policy
- IAM roles with ABAC conditions and session tag requirements
- SCP and RCP policy documents
- Cognito user pools with custom attribute mappings
- CloudTrail configuration for S3 data events
- Test IAM users/roles for each scenario
