resource "aws_api_gateway_rest_api" "dcs" {
  name        = "${var.project_name}-api"
  description = "DCS Level 1 Assured Data Access API"
}

resource "aws_api_gateway_resource" "objects" {
  rest_api_id = aws_api_gateway_rest_api.dcs.id
  parent_id   = aws_api_gateway_rest_api.dcs.root_resource_id
  path_part   = "objects"
}

resource "aws_api_gateway_resource" "object" {
  rest_api_id = aws_api_gateway_rest_api.dcs.id
  parent_id   = aws_api_gateway_resource.objects.id
  path_part   = "{objectKey}"
}

resource "aws_api_gateway_method" "get_object" {
  rest_api_id   = aws_api_gateway_rest_api.dcs.id
  resource_id   = aws_api_gateway_resource.object.id
  http_method   = "GET"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "authorizer" {
  rest_api_id             = aws_api_gateway_rest_api.dcs.id
  resource_id             = aws_api_gateway_resource.object.id
  http_method             = aws_api_gateway_method.get_object.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.authorizer.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dcs.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "dcs" {
  rest_api_id = aws_api_gateway_rest_api.dcs.id
  depends_on  = [aws_api_gateway_integration.authorizer]
}

resource "aws_api_gateway_stage" "demo" {
  deployment_id = aws_api_gateway_deployment.dcs.id
  rest_api_id   = aws_api_gateway_rest_api.dcs.id
  stage_name    = "demo"
}
