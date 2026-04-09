resource "aws_verifiedpermissions_policy_store" "dcs" {
  validation_settings {
    mode = "STRICT"
  }
  description = "DCS Level 2 - Coalition ABAC Policy Store"
}

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

resource "aws_verifiedpermissions_policy" "revoked_clearance" {
  policy_store_id = aws_verifiedpermissions_policy_store.dcs.id

  definition {
    static {
      description = "Deny all access for users with clearance level 0 (revoked)"
      statement   = <<-CEDAR
        forbid(
          principal is DCS::User,
          action == DCS::Action::"read",
          resource is DCS::DataObject
        ) when {
          principal.clearanceLevel == 0
        };
      CEDAR
    }
  }
}