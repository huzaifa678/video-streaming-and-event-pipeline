resource "aws_glue_job" "rekognition_to_redshift" {
  name     = "${var.project_name}-rekognition-etl"
  role_arn = aws_iam_role.glue_role.arn

  glue_version = "5.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.analysis_results.bucket}/scripts/rekognition_etl.py"
    python_version  = "3"
  }

    default_arguments = {
      "--TempDir"             = "s3://${aws_s3_bucket.analysis_results.bucket}/temp/"
      "--enable-xray-tracing" = "true"
      "--job-language"        = "python"
      "--additional-python-modules" = "aws-xray-sdk"
      "--S3_INPUT_PATH"       = "s3://${aws_s3_bucket.rekognition_raw.bucket}/raw/rekognition/"
      "--REDSHIFT_JDBC_URL"   = "jdbc:redshift://${aws_redshift_cluster.main.endpoint}:5439/videoanalytics"
      "--REDSHIFT_SECRET_ARN" = aws_secretsmanager_secret.redshift.arn
      "--SQS_QUEUE_URL"       = aws_sqs_queue.video_events_dlq.url
    }

  max_retries = 4
  timeout     = 10
}