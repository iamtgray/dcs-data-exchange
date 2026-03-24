# Terraform Reference - DCS Level 2: ABAC with Verified Permissions

## Prerequisites

- AWS Account with admin access
- Terraform >= 1.5
- AWS CLI configured
- Level 1 architecture understanding (recommended to build Level 1 first)

## Core Terraform configuration

### variables.tf
```hcl
variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "project_name" {
  type    = string
  default = "dcs-level-2"
}
```

### cognito.tf - Three national identity providers
```hcl
# UK User Pool
resource "aws_cognito_user_pool" "uk" {
  name = "${var.project_name}-uk-idp"

  schema {
    name                = "clearance"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 1; max_length = 50 }
  }
  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints { min_length = 2; max_length = 5 }
  }
  schema {
    name                = "saps"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 0; max_length = 200 }
  }
  schema {
    name                = "clearanceLevel"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints { min_value = 0; max_value = 5 }
  }
}

resource "aws_cognito_user_pool_client" "uk" {
  name         = "${var.project_name}-uk-client"
  user_pool_id = aws_cognito_user_pool.uk.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# Pre-create UK test users
resource "aws_cognito_user" "uk_analyst" {
  user_pool_id = aws_cognito_user_pool.uk.id
  username     = "uk-analyst-01"
  password     = "DemoP@ss2025!"
  attributes = {
    "custom:clearance"      = "SECRET"
    "custom:nationality"    = "GBR"
    "custom:saps"           = "WALL"
    "custom:clearanceLevel" = "2"
  }
}

# Poland User Pool
resource "aws_cognito_user_pool" "pol" {
  name = "${var.project_name}-pol-idp"

  schema {
    name                = "clearance"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 1; max_length = 50 }
  }
  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints { min_length = 2; max_length = 5 }
  }
  schema {
    name                = "saps"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 0; max_length = 200 }
  }
  schema {
    name                = "clearanceLevel"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints { min_value = 0; max_value = 5 }
  }
}

resource "aws_cognito_user_pool_client" "pol" {
  name         = "${var.project_name}-pol-client"
  user_pool_id = aws_cognito_user_pool.pol.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

resource "aws_cognito_user" "pol_analyst" {
  user_pool_id = aws_cognito_user_pool.pol.id
  username     = "pol-analyst-01"
  password     = "DemoP@ss2025!"
  attributes = {
    "custom:clearance"      = "NATO-SECRET"
    "custom:nationality"    = "POL"
    "custom:saps"           = ""
    "custom:clearanceLevel" = "2"
  }
}

# US User Pool
resource "aws_cognito_user_pool" "us" {
  name = "${var.project_name}-us-idp"

  schema {
    name                = "clearance"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 1; max_length = 50 }
  }
  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints { min_length = 2; max_length = 5 }
  }
  schema {
    name                = "saps"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints { min_length = 0; max_length = 200 }
  }
  schema {
    name                = "clearanceLevel"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints { min_value = 0; max_value = 5 }
  }
}

resource "aws_cognito_user_pool_client" "us" {
  name         = "${var.project_name}-us-client"
  user_pool_id = aws_cognito_user_pool.us.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

resource "aws_cognito_user" "us_analyst" {
  user_pool_id = aws_cognito_user_pool.us.id
  username     = "us-analyst-01"
  password     = "DemoP@ss2025!"
  attributes = {
    "custom:clearance"      = "IL-6"
    "custom:nationality"    = "USA"
    "custom:saps"           = "WALL"
    "custom:clearanceLevel" = "2"
  }
}
```

### verified-permissions.tf - Cedar policy store
```hcl
resource "aws_verifiedpermissions_policy_store" "dcs" {
  validation_settings {
    mode = "STRICT"
  }
  description = "DCS Level 2 - Coalition ABAC Policy Store"
}

# Schema definition
resource "aws_verifiedpermissions_schema" "dcs" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    value = jsonencode({
      "DCS" = {
        entityTypes = {
          "User" = {
            shape = {
              type = "Record"
              attributes = {
                clearanceLevel = { type = "Long", required = true }
                nationality    = { type = "String", required = true }
                saps           = { type = "Set", element = { type = "String" } }
                organisation   = { type = "String", required = true }
              }
            }
          }
          "DataObject" = {
            shape = {
              type = "Record"
              attributes = {
                classificationLevel = { type = "Long", required = true }
                releasableTo        = { type = "Set", element = { type = "String" } }
                requiredSap         = { type = "String", required = true }
                originator          = { type = "String", required = true }
              }
            }
          }
        }
        actions = {
          "read" = {
            appliesTo = {
              principalTypes = ["User"]
              resourceTypes  = ["DataObject"]
            }
          }
          "write" = {
            appliesTo = {
              principalTypes = ["User"]
              resourceTypes  = ["DataObject"]
            }
          }
          "delete" = {
            appliesTo = {
              principalTypes = ["User"]
              resourceTypes  = ["DataObject"]
            }
          }
        }
      }
    })
  }
}

# Main access policy - clearance + nationality + SAP check
resource "aws_verifiedpermissions_policy" "standard_access" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Grant read access when clearance, nationality, and SAP requirements are met"
      statement   = <<-CEDAR
        permit(
          principal is DCS::User,
          action == DCS::Action::"read",
          resource is DCS::DataObject
        ) when {
          principal.clearanceLevel >= resource.classificationLevel &&
          resource.releasableTo.contains(principal.nationality) &&
          (resource.requiredSap == "" || principal.saps.contains(resource.requiredSap))
        };
      CEDAR
    }
  }
}

# Originator access policy - originators always have access
resource "aws_verifiedpermissions_policy" "originator_access" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Originators always have read access to their own data"
      statement   = <<-CEDAR
        permit(
          principal is DCS::User,
          action == DCS::Action::"read",
          resource is DCS::DataObject
        ) when {
          principal.nationality == resource.originator
        };
      CEDAR
    }
  }
}

# Deny policy - revoked clearances
resource "aws_verifiedpermissions_policy" "revoked_clearance" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Deny all access for users with clearance level 0 (revoked)"
      statement   = <<-CEDAR
        forbid(
          principal is DCS::User,
          action,
          resource is DCS::DataObject
        ) when {
          principal.clearanceLevel == 0
        };
      CEDAR
    }
  }
}
```

### dynamodb.tf - Labeled data store
```hcl
resource "aws_dynamodb_table" "data" {
  name         = "${var.project_name}-data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "dataId"

  attribute {
    name = "dataId"
    type = "S"
  }

  attribute {
    name = "classification"
    type = "S"
  }

  global_secondary_index {
    name            = "by-classification"
    hash_key        = "classification"
    projection_type = "ALL"
  }

  tags = {
    Purpose = "DCS Level 2 labeled data store"
  }
}

# Seed test data
resource "aws_dynamodb_table_item" "intel_report" {
  table_name = aws_dynamodb_table.data.name
  hash_key   = aws_dynamodb_table.data.hash_key
  item = jsonencode({
    dataId              = { S = "intel-report-001" }
    classification      = { S = "SECRET" }
    classificationLevel = { N = "2" }
    releasableTo        = { SS = ["GBR", "USA", "POL"] }
    requiredSap         = { S = "" }
    originator          = { S = "POL" }
    created             = { S = "2025-03-15T10:30:00Z" }
    payload             = { S = "Enemy forces observed moving through northern sector. Estimated 200 personnel with armoured vehicles." }
  })
}

resource "aws_dynamodb_table_item" "wall_report" {
  table_name = aws_dynamodb_table.data.name
  hash_key   = aws_dynamodb_table.data.hash_key
  item = jsonencode({
    dataId              = { S = "wall-report-003" }
    classification      = { S = "SECRET" }
    classificationLevel = { N = "2" }
    releasableTo        = { SS = ["GBR", "USA", "POL"] }
    requiredSap         = { S = "WALL" }
    originator          = { S = "GBR" }
    created             = { S = "2025-03-16T08:15:00Z" }
    payload             = { S = "UK enriched intelligence: Operation WALL updated assessment with HUMINT sources." }
  })
}

resource "aws_dynamodb_table_item" "uk_eyes" {
  table_name = aws_dynamodb_table.data.name
  hash_key   = aws_dynamodb_table.data.hash_key
  item = jsonencode({
    dataId              = { S = "uk-eyes-only-002" }
    classification      = { S = "SECRET" }
    classificationLevel = { N = "2" }
    releasableTo        = { SS = ["GBR"] }
    requiredSap         = { S = "" }
    originator          = { S = "GBR" }
    created             = { S = "2025-03-16T14:00:00Z" }
    payload             = { S = "UK-only assessment of partner nation capabilities." }
  })
}
```

### lambda-data-service.tf
```hcl
resource "aws_lambda_function" "data_service" {
  function_name = "${var.project_name}-data-service"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.data_service.output_path
  role          = aws_iam_role.data_service_role.arn
  timeout       = 15
  memory_size   = 256

  environment {
    variables = {
      POLICY_STORE_ID = aws_verifiedpermissions_policy_store.dcs.id
      DATA_TABLE      = aws_dynamodb_table.data.name
    }
  }
}
```

## Lambda data service code

### lambda/data-service/index.py
```python
import json
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

avp = boto3.client('verifiedpermissions')
dynamodb = boto3.resource('dynamodb')

POLICY_STORE_ID = os.environ['POLICY_STORE_ID']
table = dynamodb.Table(os.environ['DATA_TABLE'])


def handler(event, context):
    """DCS Level 2 data service with ABAC authorization via Verified Permissions."""
    http_method = event.get('httpMethod', 'GET')
    data_id = event.get('pathParameters', {}).get('dataId', '')

    # Extract user attributes from Cognito JWT (passed by API Gateway)
    claims = event.get('requestContext', {}).get('authorizer', {}).get('claims', {})
    user_id = claims.get('sub', 'unknown')
    clearance_level = int(claims.get('custom:clearanceLevel', '0'))
    nationality = claims.get('custom:nationality', '')
    saps_str = claims.get('custom:saps', '')
    saps = [s.strip() for s in saps_str.split(',') if s.strip()]
    organisation = claims.get('custom:organisation', '')

    if http_method == 'GET' and data_id:
        return handle_read(user_id, clearance_level, nationality, saps, organisation, data_id)
    elif http_method == 'GET':
        return handle_list(user_id, clearance_level, nationality, saps, organisation)
    else:
        return response(405, {'error': 'Method not allowed'})


def handle_read(user_id, clearance_level, nationality, saps, org, data_id):
    """Read a specific data object after ABAC authorization."""
    # Get data item from DynamoDB
    result = table.get_item(Key={'dataId': data_id})
    item = result.get('Item')
    if not item:
        return response(404, {'error': 'Data not found'})

    # Call Amazon Verified Permissions
    try:
        avp_response = avp.is_authorized(
            policyStoreId=POLICY_STORE_ID,
            principal={
                'entityType': 'DCS::User',
                'entityId': user_id,
            },
            action={
                'actionType': 'DCS::Action',
                'actionId': 'read',
            },
            resource={
                'entityType': 'DCS::DataObject',
                'entityId': data_id,
            },
            entities={
                'entityList': [
                    {
                        'identifier': {
                            'entityType': 'DCS::User',
                            'entityId': user_id,
                        },
                        'attributes': {
                            'clearanceLevel': {'long': clearance_level},
                            'nationality': {'string': nationality},
                            'saps': {'set': [{'string': s} for s in saps]},
                            'organisation': {'string': org},
                        },
                    },
                    {
                        'identifier': {
                            'entityType': 'DCS::DataObject',
                            'entityId': data_id,
                        },
                        'attributes': {
                            'classificationLevel': {'long': int(item.get('classificationLevel', 0))},
                            'releasableTo': {'set': [{'string': n} for n in item.get('releasableTo', [])]},
                            'requiredSap': {'string': item.get('requiredSap', '')},
                            'originator': {'string': item.get('originator', '')},
                        },
                    },
                ]
            },
        )
    except Exception as e:
        logger.error(f"AVP error: {e}")
        return response(500, {'error': 'Authorization service unavailable'})

    decision = avp_response.get('decision', 'DENY')

    # Log the full authorization decision
    logger.info(json.dumps({
        'event': 'DCS_ABAC_DECISION',
        'user': user_id,
        'nationality': nationality,
        'clearanceLevel': clearance_level,
        'dataId': data_id,
        'dataClassification': item.get('classification'),
        'decision': decision,
        'determiningPolicies': [
            p['policyId'] for p in avp_response.get('determiningPolicies', [])
        ],
    }))

    if decision == 'ALLOW':
        return response(200, {
            'dataId': data_id,
            'classification': item.get('classification'),
            'originator': item.get('originator'),
            'payload': item.get('payload'),
            'accessGrantedBy': 'DCS-Level-2-ABAC',
        })
    else:
        return response(403, {
            'authorized': False,
            'dataId': data_id,
            'decision': decision,
            'message': 'Access denied by DCS ABAC policy',
        })


def handle_list(user_id, clearance_level, nationality, saps, org):
    """List all data objects (metadata only, no payloads)."""
    result = table.scan(
        ProjectionExpression='dataId, classification, originator, created, releasableTo, requiredSap'
    )
    items = result.get('Items', [])

    # Convert sets to lists for JSON serialization
    for item in items:
        if 'releasableTo' in item:
            item['releasableTo'] = list(item['releasableTo'])

    return response(200, {
        'count': len(items),
        'items': items,
        'note': 'Listing shows metadata only. Access payload via GET /data/{dataId}'
    })


def response(status, body):
    return {
        'statusCode': status,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
        'body': json.dumps(body, default=str),
    }
```

## Manual setup instructions

If building by hand in the AWS Console:

1. **Create three Cognito User Pools** (UK, Poland, US) with custom attributes
2. **Create users** in each pool with clearance, nationality, SAP attributes
3. **Create Verified Permissions policy store** with the Cedar schema above
4. **Add Cedar policies** (standard access, originator, revoked)
5. **Create DynamoDB table** and seed test data items
6. **Create Lambda function** with the data service code
7. **Create API Gateway** with Cognito authorizer
8. **Test** by authenticating as different users and accessing different data items

See the interactive guide (guide/index.html) for a detailed walkthrough.
