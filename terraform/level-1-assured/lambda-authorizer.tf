resource "aws_lambda_function" "authorizer" {
  function_name = "${var.project_name}-authorizer"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.authorizer.output_path
  role          = aws_iam_role.authorizer_role.arn
  timeout       = 15
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

data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/authorizer"
  output_path = "${path.module}/lambda/authorizer.zip"
}

resource "aws_iam_role" "authorizer_role" {
  name = "${var.project_name}-authorizer-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "authorizer_policy" {
  name = "${var.project_name}-authorizer-policy"
  role = aws_iam_role.authorizer_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadS3Data"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Sid      = "ReadLabelStore"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Query"]
        Resource = [
          aws_dynamodb_table.labels.arn,
          "${aws_dynamodb_table.labels.arn}/index/*"
        ]
      },
      {
        Sid      = "VerifySignatures"
        Effect   = "Allow"
        Action   = ["kms:Verify", "kms:GetPublicKey"]
        Resource = aws_kms_key.label_signing.arn
      },
      {
        Sid      = "ReadUserTags"
        Effect   = "Allow"
        Action   = ["iam:GetUser", "iam:ListUserTags"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.project_name}-*"
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
