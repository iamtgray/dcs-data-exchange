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

output "platform_ip" {
  description = "Elastic IP for the OpenTDF platform"
  value       = aws_eip.opentdf.public_ip
}

output "platform_url" {
  description = "OpenTDF platform URL"
  value       = "http://${aws_eip.opentdf.public_ip}:8080"
}

output "cognito_uk_client_id" {
  description = "Cognito app client ID (pass-through from Level 2)"
  value       = var.cognito_uk_client_id
}

output "cognito_uk_pool_id" {
  description = "Cognito User Pool ID (pass-through from Level 2)"
  value       = var.cognito_uk_pool_id
}

output "kas_rsa_public_key_pem" {
  description = "KAS RSA public key certificate (PEM)"
  value       = tls_self_signed_cert.kas_rsa.cert_pem
  sensitive   = true
}

output "kas_ec_public_key_pem" {
  description = "KAS EC public key certificate (PEM)"
  value       = tls_self_signed_cert.kas_ec.cert_pem
  sensitive   = true
}

output "kas_rsa_private_key_pem" {
  description = "KAS RSA private key (PEM) - for key wrapping during provisioning"
  value       = tls_private_key.kas_rsa.private_key_pem
  sensitive   = true
}
