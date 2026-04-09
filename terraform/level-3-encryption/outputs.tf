output "kms_key_id" {
  description = "KMS Key Encryption Key ID"
  value       = aws_kms_key.kas_kek.key_id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.opentdf.address
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.opentdf.name
}

output "cognito_issuer_url" {
  description = "Cognito OIDC issuer URL for the OpenTDF platform"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_uk_pool_id}"
}

output "cognito_uk_client_id" {
  description = "Cognito app client ID (pass-through from Level 2)"
  value       = var.cognito_uk_client_id
}

output "cognito_uk_pool_id" {
  description = "Cognito User Pool ID (pass-through from Level 2)"
  value       = var.cognito_uk_pool_id
}
