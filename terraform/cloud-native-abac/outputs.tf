output "data_bucket_name" {
  value = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  value = aws_s3_bucket.data.arn
}

output "data_reader_role_arn" {
  value = aws_iam_role.data_reader.arn
}

output "data_writer_role_arn" {
  value = aws_iam_role.data_writer.arn
}

output "label_admin_role_arn" {
  value = aws_iam_role.label_admin.arn
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.coalition.id
}

output "cognito_user_pools" {
  value = {
    for k, v in aws_cognito_user_pool.nation : k => {
      id       = v.id
      endpoint = v.endpoint
    }
  }
}

output "cloudtrail_arn" {
  value = aws_cloudtrail.dcs.arn
}
