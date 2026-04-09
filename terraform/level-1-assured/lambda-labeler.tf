resource "aws_lambda_function" "labeler" {
  function_name = "${var.project_name}-labeler"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.labeler.output_path
  role          = aws_iam_role.labeler_role.arn
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      DATA_BUCKET    = aws_s3_bucket.data.id
      LABEL_TABLE    = aws_dynamodb_table.labels.name
      SIGNING_KEY_ID = aws_kms_key.label_signing.key_id
    }
  }

  layers = [aws_lambda_layer_version.lxml_layer.arn]
}

data "archive_file" "labeler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/labeler"
  output_path = "${path.module}/lambda/labeler.zip"
}

resource "aws_lambda_layer_version" "lxml_layer" {
  filename            = "${path.module}/lambda/layers/lxml-layer.zip"
  layer_name          = "${var.project_name}-lxml"
  compatible_runtimes = ["python3.12"]
  description         = "lxml XML processing library for STANAG 4774 label generation"
}

resource "aws_iam_role" "labeler_role" {
  name = "${var.project_name}-labeler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "labeler_policy" {
  name = "${var.project_name}-labeler-policy"
  role = aws_iam_role.labeler_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadS3Data"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:HeadObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Sid      = "WriteLabelStore"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.labels.arn
      },
      {
        Sid      = "SignLabels"
        Effect   = "Allow"
        Action   = ["kms:Sign"]
        Resource = aws_kms_key.label_signing.arn
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
