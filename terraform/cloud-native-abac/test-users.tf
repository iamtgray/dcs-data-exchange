# Create test users in each national pool for scenario testing

resource "aws_cognito_user" "test_users" {
  for_each = var.nations

  user_pool_id = aws_cognito_user_pool.nation[
    each.value.nationality == "GBR" ? "gbr" :
    each.value.nationality == "POL" ? "pol" : "usa"
  ].id

  username = "test-${each.key}"

  attributes = {
    "custom:clearance"    = tostring(each.value.clearance_level)
    "custom:nationality"  = each.value.nationality
    "custom:sap"          = length(each.value.saps) > 0 ? join(",", each.value.saps) : "NONE"
    "custom:organisation" = each.value.organisation
  }
}
