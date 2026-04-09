output "api_url" {
  description = "API Gateway URL for the DCS data service"
  value       = aws_api_gateway_stage.demo.invoke_url
}

output "data_bucket_name" {
  description = "Name of the S3 data bucket"
  value       = aws_s3_bucket.data.id
}

output "label_table_name" {
  description = "Name of the DynamoDB label store"
  value       = aws_dynamodb_table.labels.name
}

output "signing_key_id" {
  description = "KMS signing key ID for STANAG 4778 binding"
  value       = aws_kms_key.label_signing.key_id
}
