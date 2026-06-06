resource "aws_s3_object" "rekognition_etl_script" {
  bucket = var.analysis_results_bucket_id
  key    = "scripts/rekognition_etl.py"
  source = "${var.source_root}/scripts/rekognition_etl.py"
  etag   = filemd5("${var.source_root}/scripts/rekognition_etl.py")
}

resource "aws_glue_job" "rekognition_to_redshift" {
  name     = "${var.project_name}-rekognition-etl"
  role_arn = aws_iam_role.glue_role.arn

  glue_version      = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://${var.analysis_results_bucket_name}/scripts/rekognition_etl.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"                   = "s3://${var.analysis_results_bucket_name}/temp/"
    "--enable-xray-tracing"       = "true"
    "--job-language"              = "python"
    "--additional-python-modules" = "aws-xray-sdk"
    "--S3_INPUT_PATH"             = "s3://${var.rekognition_raw_bucket_name}/raw/rekognition/"
    "--REDSHIFT_JDBC_URL"         = "jdbc:redshift://${var.redshift_endpoint}:5439/videoanalytics"
    "--REDSHIFT_SECRET_ARN"       = var.redshift_secret_arn
  }

  max_retries = 4
  timeout     = 120
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
        Retry = [{
          ErrorEquals     = ["Glue.ConcurrentRunsExceededException", "States.TaskFailed"]
          IntervalSeconds = 30
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          ResultPath  = "$.error"
          Next        = "SendToDLQ"
        }]
        End = true
      }
      SendToDLQ = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl = var.sqs_dlq_url
          MessageBody = {
            "source"           = "step-functions:glue-orchestrator"
            "job"              = aws_glue_job.rekognition_to_redshift.name
            "executionId.$"    = "$$.Execution.Id"
            "stateEnteredAt.$" = "$$.State.EnteredTime"
            "error.$"          = "$.error"
            "input.$"          = "$$.Execution.Input"
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

resource "aws_cloudwatch_event_rule" "s3_rekognition_trigger" {
  name        = "trigger-glue-on-s3-upload"
  description = "Trigger Step Function when Rekognition results land in S3"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.rekognition_raw_bucket_name]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sfn_target" {
  rule      = aws_cloudwatch_event_rule.s3_rekognition_trigger.name
  target_id = "GlueOrchestratorStateMachine"
  arn       = aws_sfn_state_machine.glue_orchestrator.arn
  role_arn  = aws_iam_role.eventbridge_invoke_sfn.arn
}
