resource "aws_lambda_function" "authorizer" {
  function_name = "${var.project_name}-authorizer"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.authorizer.output_path
  role          = aws_iam_role.authorizer_role.arn
  timeout       = 10
  memory_size   = 256

  environment {
    variables = {
      DATA_BUCKET           = aws_s3_bucket.data.id
      CLASSIFICATION_LEVELS = jsonencode(var.classification_levels)
    }
  }
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
        Effect   = "Allow"
        Action   = ["s3:GetObjectTagging"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:GetUser", "iam:ListUserTags"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.project_name}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
