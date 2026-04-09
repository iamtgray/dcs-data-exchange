# ---------------------------------------------------------------------------
# Cognito User Pools (one per nation)
# ---------------------------------------------------------------------------
locals {
  nations = {
    uk = {
      pool_name   = "dcs-level2-uk-idp"
      client_name = "dcs-uk-client"
      user        = "uk-analyst-01"
      clearance   = "SECRET"
      nationality = "GBR"
      saps        = "WALL"
      level       = "2"
    }
    pol = {
      pool_name   = "dcs-level2-pol-idp"
      client_name = "dcs-pol-client"
      user        = "pol-analyst-01"
      clearance   = "NATO-SECRET"
      nationality = "POL"
      saps        = ""
      level       = "2"
    }
    us = {
      pool_name   = "dcs-level2-us-idp"
      client_name = "dcs-us-client"
      user        = "us-analyst-01"
      clearance   = "IL-6"
      nationality = "USA"
      saps        = "WALL"
      level       = "2"
    }
  }
}

resource "aws_cognito_user_pool" "nation" {
  for_each = local.nations
  name     = each.value.pool_name

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }

  schema {
    name                = "clearance"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 50
    }
  }
  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints {
      min_length = 2
      max_length = 5
    }
  }
  schema {
    name                = "saps"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 200
    }
  }
  schema {
    name                = "clearanceLevel"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = "0"
      max_value = "5"
    }
  }
}

resource "aws_cognito_user_pool_client" "nation" {
  for_each     = local.nations
  name         = each.value.client_name
  user_pool_id = aws_cognito_user_pool.nation[each.key].id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  generate_secret = false
}

resource "aws_cognito_user" "analyst" {
  for_each     = local.nations
  user_pool_id = aws_cognito_user_pool.nation[each.key].id
  username     = each.value.user
  password     = var.user_password

  attributes = {
    "custom:clearance"      = each.value.clearance
    "custom:nationality"    = each.value.nationality
    "custom:saps"           = each.value.saps
    "custom:clearanceLevel" = each.value.level
  }
}

# ---------------------------------------------------------------------------
# Verified Permissions -- Policy Store, Schema, Cedar Policies
# ---------------------------------------------------------------------------
resource "aws_verifiedpermissions_policy_store" "dcs" {
  description = "DCS Level 2 - Coalition ABAC policies"
  validation_settings {
    mode = "STRICT"
  }
}

resource "aws_verifiedpermissions_schema" "dcs" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    value = jsonencode({
      DCS = {
        entityTypes = {
          User = {
            shape = {
              type = "Record"
              attributes = {
                clearanceLevel = { type = "Long", required = true }
                nationality    = { type = "String", required = true }
                saps           = { type = "Set", element = { type = "String" } }
              }
            }
          }
          DataObject = {
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
          read = {
            appliesTo = {
              principalTypes = ["User"]
              resourceTypes  = ["DataObject"]
            }
          }
          write = {
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

# Policy 1: Standard access -- clearance + nationality + SAP
resource "aws_verifiedpermissions_policy" "standard_access" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Standard access - clearance, nationality, and SAP check"
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

# Policy 2: Originator access -- data creators always have access
resource "aws_verifiedpermissions_policy" "originator_access" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Originator access - data creators always have access"
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

# Policy 3: Block revoked clearances
resource "aws_verifiedpermissions_policy" "block_revoked" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Block users with revoked clearance (level 0)"
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
