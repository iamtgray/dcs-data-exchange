# ---------------------------------------------------------------------------
# S3 Data Bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "data" {
  bucket = "dcs-lab-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Test Data Objects with DCS Labels (S3 tags)
# ---------------------------------------------------------------------------
resource "aws_s3_object" "logistics_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "logistics-report.txt"
  content      = <<-EOT
    LOGISTICS SUMMARY - Q1 2025
    Supply levels normal across all forward operating bases.
    No classified information in this report.
  EOT
  content_type = "text/plain"
  tags = {
    "dcs:classification" = "UNCLASSIFIED"
    "dcs:releasable-to"  = "ALL"
    "dcs:sap"            = "NONE"
    "dcs:originator"     = "USA"
  }
}

resource "aws_s3_object" "intel_report" {
  bucket       = aws_s3_bucket.data.id
  key          = "intel-report.txt"
  content      = <<-EOT
    INTELLIGENCE ASSESSMENT - NORTHERN SECTOR
    Enemy forces observed moving through GRID 12345678.
    Estimated 200 personnel with armoured vehicles.
    Movement pattern suggests preparation for offensive operations.
    Recommend increased surveillance.
  EOT
  content_type = "text/plain"
  tags = {
    "dcs:classification" = "SECRET"
    "dcs:releasable-to"  = "GBR USA POL"
    "dcs:sap"            = "NONE"
    "dcs:originator"     = "POL"
  }
}

resource "aws_s3_object" "operation_wall" {
  bucket       = aws_s3_bucket.data.id
  key          = "operation-wall.txt"
  content      = <<-EOT
    OPERATION WALL - PHASE 2 UPDATE
    UK HUMINT sources report enemy command structure reorganisation.
    Source reliability: A2. Information confirmed by SIGINT.
    Coalition response options being developed.
  EOT
  content_type = "text/plain"
  tags = {
    "dcs:classification" = "SECRET"
    "dcs:releasable-to"  = "GBR USA POL"
    "dcs:sap"            = "WALL"
    "dcs:originator"     = "GBR"
  }
}

# ---------------------------------------------------------------------------
# Lambda Execution Role (starts with Lab 1 permissions, Lab 2 adds AVP)
# ---------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "dcs-lab-data-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda" {
  name = "dcs-lab-data-service-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectTagging"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = "verifiedpermissions:IsAuthorized"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# Lambda Function (Lab 2 version with Verified Permissions)
# ---------------------------------------------------------------------------
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/lab2.py"
  output_path = "${path.module}/lambda/lab2.zip"
}

resource "aws_lambda_function" "data_service" {
  function_name    = "dcs-lab-data-service"
  role             = aws_iam_role.lambda.arn
  handler          = "lab2.lambda_handler"
  runtime          = "python3.12"
  timeout          = 15
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      DATA_BUCKET     = aws_s3_bucket.data.id
      POLICY_STORE_ID = aws_verifiedpermissions_policy_store.dcs.id
    }
  }
}

resource "aws_lambda_function_url" "data_service" {
  function_name      = aws_lambda_function.data_service.function_name
  authorization_type = "NONE"
}
