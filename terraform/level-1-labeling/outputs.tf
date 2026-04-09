output "api_url" {
  description = "API Gateway URL for the DCS data service"
  value       = aws_api_gateway_stage.demo.invoke_url
}

output "data_bucket_name" {
  description = "Name of the S3 data bucket"
  value       = aws_s3_bucket.data.id
}

output "audit_bucket_name" {
  description = "Name of the S3 audit bucket"
  value       = aws_s3_bucket.audit.id
}
