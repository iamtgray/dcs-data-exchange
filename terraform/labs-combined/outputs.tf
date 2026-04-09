output "data_bucket" {
  value = aws_s3_bucket.data.id
}

output "lambda_function_url" {
  value = aws_lambda_function_url.data_service.function_url
}

output "policy_store_id" {
  value = aws_verifiedpermissions_policy_store.dcs.id
}

output "cognito_uk_pool_id" {
  value = aws_cognito_user_pool.nation["uk"].id
}

output "cognito_uk_client_id" {
  value = aws_cognito_user_pool_client.nation["uk"].id
}

output "cognito_pol_pool_id" {
  value = aws_cognito_user_pool.nation["pol"].id
}

output "cognito_pol_client_id" {
  value = aws_cognito_user_pool_client.nation["pol"].id
}

output "cognito_us_pool_id" {
  value = aws_cognito_user_pool.nation["us"].id
}

output "cognito_us_client_id" {
  value = aws_cognito_user_pool_client.nation["us"].id
}

output "kms_key_id" {
  value = aws_kms_key.kas_kek.key_id
}

output "rds_endpoint" {
  value = aws_db_instance.opentdf.address
}

output "ecs_cluster" {
  value = aws_ecs_cluster.opentdf.name
}

output "cognito_issuer_url" {
  value = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.nation["uk"].id}"
}
