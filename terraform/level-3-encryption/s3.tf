resource "aws_s3_bucket" "tdf_data" {
  bucket = "dcs-lab-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "tdf_data" {
  bucket = aws_s3_bucket.tdf_data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "tdf_data" {
  bucket                  = aws_s3_bucket.tdf_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
