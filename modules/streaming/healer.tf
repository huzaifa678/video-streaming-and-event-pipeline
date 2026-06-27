locals {
  stream_processor_name = aws_rekognition_stream_processor.video_processor.name
}

resource "aws_cloudwatch_log_group" "kvs_healer" {
  name              = "/aws/states/${var.project_name}-kvs-healer"
  retention_in_days = 14
}

resource "aws_iam_role" "kvs_healer_sfn" {
  name = "${var.project_name}-kvs-healer-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "kvs_healer_sfn" {
  name = "${var.project_name}-kvs-healer-sfn-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rekognition:DescribeStreamProcessor",
          "rekognition:StartStreamProcessor",
          "rekognition:StopStreamProcessor"
        ]
        Resource = aws_rekognition_stream_processor.video_processor.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = var.sqs_dlq_arn
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

resource "aws_iam_role_policy_attachment" "kvs_healer_sfn" {
  role       = aws_iam_role.kvs_healer_sfn.name
  policy_arn = aws_iam_policy.kvs_healer_sfn.arn
}

resource "aws_sfn_state_machine" "kvs_healer" {
  name     = "${var.project_name}-kvs-healer"
  role_arn = aws_iam_role.kvs_healer_sfn.arn

  tracing_configuration {
    enabled = true
  }

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.kvs_healer.arn}:*"
    include_execution_data = true
    level                  = "ERROR"
  }

  definition = jsonencode({
    Comment = "Detect Rekognition stream processor in FAILED state and restart it. DLQ on persistent failure."
    StartAt = "Describe"
    States = {
      Describe = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:rekognition:describeStreamProcessor"
        Parameters = {
          Name = local.stream_processor_name
        }
        ResultPath = "$.describe"
        Next       = "RouteOnStatus"
      }
      RouteOnStatus = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.describe.Status"
            StringEquals = "FAILED"
            Next         = "Restart"
          },
          {
            Variable     = "$.describe.Status"
            StringEquals = "STOPPED"
            Next         = "Restart"
          }
        ]
        Default = "NoActionNeeded"
      }
      NoActionNeeded = {
        Type = "Succeed"
      }
      Restart = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:rekognition:startStreamProcessor"
        Parameters = {
          Name = local.stream_processor_name
        }
        ResultPath = "$.start"
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = 5
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "ReportFailure"
        }]
        Next = "WaitAfterStart"
      }
      WaitAfterStart = {
        Type    = "Wait"
        Seconds = 20
        Next    = "Verify"
      }
      Verify = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:rekognition:describeStreamProcessor"
        Parameters = {
          Name = local.stream_processor_name
        }
        ResultPath = "$.verify"
        Next       = "VerifyChoice"
      }
      VerifyChoice = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.verify.Status"
            StringEquals = "RUNNING"
            Next         = "Healed"
          },
          {
            Variable     = "$.verify.Status"
            StringEquals = "STARTING"
            Next         = "Healed"
          }
        ]
        Default = "ReportFailure"
      }
      Healed = {
        Type = "Succeed"
      }
      ReportFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl = var.sqs_dlq_url
          MessageBody = {
            "source"           = "step-functions:kvs-healer"
            "streamProcessor"  = local.stream_processor_name
            "executionId.$"    = "$$.Execution.Id"
            "stateEnteredAt.$" = "$$.State.EnteredTime"
            "lastKnownState.$" = "$"
          }
        }
        Next = "Fail"
      }
      Fail = {
        Type  = "Fail"
        Error = "KvsHealerCouldNotRecover"
        Cause = "Stream processor did not return to RUNNING after restart"
      }
    }
  })
}

# Scheduled trigger via EventBridge.
resource "aws_iam_role" "kvs_healer_scheduler" {
  name = "${var.project_name}-kvs-healer-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "kvs_healer_scheduler" {
  name = "${var.project_name}-kvs-healer-scheduler"
  role = aws_iam_role.kvs_healer_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.kvs_healer.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "kvs_healer_schedule" {
  name                = "${var.project_name}-kvs-healer-schedule"
  description         = "Periodically run the KVS healer Step Function"
  schedule_expression = var.healer_schedule
}

resource "aws_cloudwatch_event_target" "kvs_healer_schedule" {
  rule      = aws_cloudwatch_event_rule.kvs_healer_schedule.name
  target_id = "KvsHealerStateMachine"
  arn       = aws_sfn_state_machine.kvs_healer.arn
  role_arn  = aws_iam_role.kvs_healer_scheduler.arn
}
