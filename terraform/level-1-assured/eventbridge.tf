resource "aws_cloudwatch_event_rule" "s3_put" {
  name        = "${var.project_name}-s3-put"
  description = "Trigger label creation on S3 PutObject"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.data.id] }
    }
  })
}

resource "aws_cloudwatch_event_target" "labeler" {
  rule      = aws_cloudwatch_event_rule.s3_put.name
  target_id = "labeler"
  arn       = aws_lambda_function.labeler.arn
}

resource "aws_lambda_permission" "eventbridge_labeler" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.labeler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_put.arn
}
