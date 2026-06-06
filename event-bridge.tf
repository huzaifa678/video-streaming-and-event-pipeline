resource "aws_cloudwatch_event_rule" "s3_rekognition_trigger" {
  name        = "trigger-glue-on-s3-upload"
  description = "Trigger Step Function when Rekognition results land in S3"

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

resource "aws_iam_role" "eventbridge_invoke_sfn" {
  name = "${var.project_name}-eb-invoke-sfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_invoke_sfn" {
  name = "${var.project_name}-eb-invoke-sfn"
  role = aws_iam_role.eventbridge_invoke_sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.glue_orchestrator.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule     = aws_cloudwatch_event_rule.s3_rekognition_trigger.name
  target_id = "GlueOrchestratorStateMachine"
  arn      = aws_sfn_state_machine.glue_orchestrator.arn
  role_arn = aws_iam_role.eventbridge_invoke_sfn.arn
}
