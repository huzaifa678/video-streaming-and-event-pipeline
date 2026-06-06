resource "aws_iam_role" "sfn_glue_orchestrator" {
  name = "${var.project_name}-sfn-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "sfn_glue_orchestrator" {
  name = "${var.project_name}-sfn-glue-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.video_events_dlq.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords", "xray:GetSamplingRules", "xray:GetSamplingTargets"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_glue_orchestrator" {
  role       = aws_iam_role.sfn_glue_orchestrator.name
  policy_arn = aws_iam_policy.sfn_glue_orchestrator.arn
}

resource "aws_cloudwatch_log_group" "sfn_glue_orchestrator" {
  name              = "/aws/states/${var.project_name}-glue-orchestrator"
  retention_in_days = 14
}

resource "aws_sfn_state_machine" "glue_orchestrator" {
  name     = "${var.project_name}-glue-orchestrator"
  role_arn = aws_iam_role.sfn_glue_orchestrator.arn

  tracing_configuration {
    enabled = true
  }

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_glue_orchestrator.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  definition = jsonencode({
    Comment = "Bridge: EventBridge S3 trigger -> Glue rekognition ETL with DLQ on failure"
    StartAt = "StartGlueJob"
    States = {
      StartGlueJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.rekognition_to_redshift.name
        }
        Retry = [
          {
            ErrorEquals     = ["Glue.ConcurrentRunsExceededException", "States.TaskFailed"]
            IntervalSeconds = 30
            MaxAttempts     = 2
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "SendToDLQ"
          }
        ]
        End = true
      }
      SendToDLQ = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl = aws_sqs_queue.video_events_dlq.url
          MessageBody = {
            "source"          = "step-functions:glue-orchestrator"
            "job"             = aws_glue_job.rekognition_to_redshift.name
            "executionId.$"   = "$$.Execution.Id"
            "stateEnteredAt.$" = "$$.State.EnteredTime"
            "error.$"         = "$.error"
            "input.$"         = "$$.Execution.Input"
          }
        }
        Next = "Fail"
      }
      Fail = {
        Type  = "Fail"
        Error = "GlueJobFailed"
        Cause = "Glue ETL failed; details sent to DLQ"
      }
    }
  })
}
