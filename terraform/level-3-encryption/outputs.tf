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
