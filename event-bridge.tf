resource "aws_cloudwatch_event_rule" "s3_rekognition_trigger" {
  name        = "trigger-glue-on-s3-upload"
  description = "Trigger Lambda when Rekognition results land in S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.rekognition_raw.bucket]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_rekognition_trigger.name
  target_id = "StartGlueLambda"
  arn       = aws_lambda_function.start_glue.arn
}
