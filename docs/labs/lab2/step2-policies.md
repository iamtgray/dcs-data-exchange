# Step 2: Create the Policy Engine

This is the big upgrade from Lab 1. Instead of hard-coding access logic in a Lambda function, we'll define policies in **Amazon Verified Permissions** using the **Cedar** policy language. Cedar lets us write human-readable rules that the service evaluates for us.

## Create a Policy Store

1. Go to **Amazon Verified Permissions Console**: [https://console.aws.amazon.com/verifiedpermissions](https://console.aws.amazon.com/verifiedpermissions)
2. Click **Create policy store**
3. Choose **Create with an empty policy store**
4. **Description**: `DCS Level 2 - Coalition ABAC policies`
5. Click **Create policy store**
6. Note down the **Policy Store ID** (you'll need it later)

## Define the Schema

The schema tells Verified Permissions what your entities (users, data objects) and actions look like.

1. In your policy store, go to **Schema**
2. Click **Edit schema** then choose the **JSON mode** editor
3. Paste this schema:

```json
{
  "DCS": {
    "entityTypes": {
      "User": {
        "shape": {
          "type": "Record",
          "attributes": {
            "clearanceLevel": { "type": "Long", "required": true },
            "nationality": { "type": "String", "required": true },
            "saps": {
              "type": "Set",
              "element": { "type": "String" }
            }
          }
        }
      },
      "DataObject": {
        "shape": {
          "type": "Record",
          "attributes": {
            "classificationLevel": { "type": "Long", "required": true },
            "releasableTo": {
              "type": "Set",
              "element": { "type": "String" }
            },
            "requiredSap": { "type": "String", "required": true },
            "originator": { "type": "String", "required": true }
          }
        }
      }
    },
    "actions": {
      "read": {
        "appliesTo": {
          "principalTypes": ["User"],
          "resourceTypes": ["DataObject"]
        }
      },
      "write": {
        "appliesTo": {
          "principalTypes": ["User"],
          "resourceTypes": ["DataObject"]
        }
      }
    }
  }
}
```

4. Click **Save changes**

This schema defines:

- **Users** have a clearance level (number), nationality (text), and a set of SAPs
- **DataObjects** have a classification level (number), a set of releasable-to countries, a required SAP, and an originator
- Users can **read** or **write** data objects

## Add Cedar Policies

### Policy 1: Standard access (clearance + nationality + SAP)

1. Go to **Policies** > **Create policy** > **Create static policy**
2. **Description**: `Standard access - clearance, nationality, and SAP check`
3. **Policy body**:

```cedar
permit(
  principal is DCS::User,
  action == DCS::Action::"read",
  resource is DCS::DataObject
) when {
  principal.clearanceLevel >= resource.classificationLevel &&
  resource.releasableTo.contains(principal.nationality) &&
  (resource.requiredSap == "" || principal.saps.contains(resource.requiredSap))
};
```

4. Click **Create policy**

**What this says in plain English**: Allow a user to read a data object when:

- Their clearance level is at least as high as the data's classification level, AND
- Their nationality is in the data's releasable-to list, AND
- Either the data doesn't require a SAP, or the user has the required SAP

### Policy 2: Originator access

1. Create another static policy
2. **Description**: `Originator access - data creators always have access`
3. **Policy body**:

```cedar
permit(
  principal is DCS::User,
  action == DCS::Action::"read",
  resource is DCS::DataObject
) when {
  principal.nationality == resource.originator
};
```

4. Click **Create policy**

**What this says**: Users from the same country that created the data always have read access.

### Policy 3: Block revoked clearances

1. Create another static policy
2. **Description**: `Block users with revoked clearance (level 0)`
3. **Policy body**:

```cedar
forbid(
  principal is DCS::User,
  action,
  resource is DCS::DataObject
) when {
  principal.clearanceLevel == 0
};
```

4. Click **Create policy**

**What this says**: Users with clearance level 0 (revoked) are denied access to everything.

## Test the policies

Verified Permissions has a built-in test feature:

1. Go to **Test bench** in the left menu
2. Fill in:
    - **Principal**: `DCS::User::"uk-analyst-01"`
    - Add attributes: `clearanceLevel: 2`, `nationality: "GBR"`, `saps: {"WALL"}`
    - **Action**: `DCS::Action::"read"`
    - **Resource**: `DCS::DataObject::"intel-report-001"`
    - Add attributes: `classificationLevel: 2`, `releasableTo: {"GBR", "USA", "POL"}`, `requiredSap: ""`, `originator: "POL"`
3. Click **Run authorization request**
4. Result should be **ALLOW**

Try changing the principal's `clearanceLevel` to `0` and run again - you should get **DENY**.

!!! tip "Cedar is powerful"
    We wrote three short policies that handle all our access scenarios. Compare this to Lab 1 where we wrote a Python function with if/else logic. Cedar policies are declarative (you say what's allowed, not how to check), testable, and changeable without code deploys.

Next: **[Step 3: Store Labeled Data](step3-data.md)**
