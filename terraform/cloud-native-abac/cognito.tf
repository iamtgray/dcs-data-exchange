# --- National Cognito User Pools (simulating national IdPs) ---

resource "aws_cognito_user_pool" "nation" {
  for_each = {
    gbr = { name = "UK", nationality = "GBR" }
    pol = { name = "Poland", nationality = "POL" }
    usa = { name = "US", nationality = "USA" }
  }

  name = "${var.project_name}-${each.key}-users"

  schema {
    name                = "clearance"
    attribute_data_type = "Number"
    mutable             = true
    number_attribute_constraints {
      min_value = "0"
      max_value = "3"
    }
  }

  schema {
    name                = "nationality"
    attribute_data_type = "String"
    mutable             = false
    string_attribute_constraints {
      min_length = "3"
      max_length = "3"
    }
  }

  schema {
    name                = "sap"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = "0"
      max_length = "256"
    }
  }

  schema {
    name                = "organisation"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = "0"
      max_length = "256"
    }
  }

  tags = {
    Project = var.project_name
    Nation  = each.value.nationality
  }
}

resource "aws_cognito_user_pool_client" "nation" {
  for_each = aws_cognito_user_pool.nation

  name         = "${each.key}-client"
  user_pool_id = each.value.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# --- Cognito Identity Pool (federates all nations into IAM roles) ---

resource "aws_cognito_identity_pool" "coalition" {
  identity_pool_name               = "${var.project_name}-coalition"
  allow_unauthenticated_identities = false

  dynamic "cognito_identity_providers" {
    for_each = aws_cognito_user_pool_client.nation
    content {
      client_id               = cognito_identity_providers.value.id
      provider_name           = aws_cognito_user_pool.nation[cognito_identity_providers.key].endpoint
      server_side_token_check = true
    }
  }
}

resource "aws_cognito_identity_pool_roles_attachment" "coalition" {
  identity_pool_id = aws_cognito_identity_pool.coalition.id

  roles = {
    "authenticated" = aws_iam_role.data_reader.arn
  }
}
