resource "aws_cloudwatch_event_rule" "s3_rekognition_trigger" {
  name        = "trigger-glue-on-s3-upload"
  description = "Trigger Lambda when Rekognition results land in S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.rekognition_raw.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_rekognition_trigger.name
  target_id = "StartGlueLambda"
  arn       = aws_lambda_function.start_glue.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_glue.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_rekognition_trigger.arn
}
