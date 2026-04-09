output "policy_store_id" {
  description = "Verified Permissions policy store ID"
  value       = aws_verifiedpermissions_policy_store.dcs.id
}

output "data_table_name" {
  description = "DynamoDB data table name"
  value       = aws_dynamodb_table.data.name
}

output "cognito_uk_pool_id" {
  description = "UK Cognito User Pool ID"
  value       = aws_cognito_user_pool.uk.id
}

output "cognito_pol_pool_id" {
  description = "Poland Cognito User Pool ID"
  value       = aws_cognito_user_pool.pol.id
}

output "cognito_us_pool_id" {
  description = "US Cognito User Pool ID"
  value       = aws_cognito_user_pool.us.id
}

output "cognito_uk_client_id" {
  description = "UK Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.uk.id
}
