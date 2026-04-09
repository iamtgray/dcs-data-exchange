resource "aws_lambda_function" "data_service" {
  function_name = "${var.project_name}-data-service"
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.data_service.output_path
  role          = aws_iam_role.data_service_role.arn
  timeout       = 15
  memory_size   = 256

  environment {
    variables = {
      POLICY_STORE_ID = aws_verifiedpermissions_policy_store.dcs.id
      DATA_TABLE      = aws_dynamodb_table.data.name
    }
  }
}

data "archive_file" "data_service" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/data-service"
  output_path = "${path.module}/lambda/data-service.zip"
}

resource "aws_iam_role" "data_service_role" {
  name = "${var.project_name}-data-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}


resource "aws_iam_role_policy" "data_service_policy" {
  name = "${var.project_name}-data-service-policy"
  role = aws_iam_role.data_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:Scan", "dynamodb:Query"]
        Resource = [
          aws_dynamodb_table.data.arn,
          "${aws_dynamodb_table.data.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "verifiedpermissions:IsAuthorized"
        Resource = aws_verifiedpermissions_policy_store.dcs.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}