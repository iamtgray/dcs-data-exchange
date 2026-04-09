# UK User Pool
resource "aws_cognito_user_pool" "uk" {
  name = "${var.project_name}-uk-idp"

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
      min_value = 0
      max_value = 5
    }
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
      min_value = 0
      max_value = 5
    }
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
      min_value = 0
      max_value = 5
    }
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