data "archive_file" "ingest_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/ingestion.py"
  output_path = "${path.module}/builds/ingest.zip"
}

data "archive_file" "processing_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/processing.py"
  output_path = "${path.module}/builds/processing.zip"
}

data "archive_file" "query_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/query.py"
  output_path = "${path.module}/builds/query.zip"
}

data "archive_file" "start_glue_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/start_glue.py"
  output_path = "${path.module}/builds/start_glue.zip"
}

data "archive_file" "index_faces_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/index_faces.py"
  output_path = "${path.module}/builds/index_faces.zip"
}

data "archive_file" "python_lib_zip" {
  type        = "zip"
  source_dir = "${path.module}/python_layer"
  output_path = "${path.module}/builds/python_lib.zip"
}

resource "aws_lambda_layer_version" "python_dependencies" {
  layer_name          = "python-dependencies"
  filename            = data.archive_file.python_lib_zip.output_path
  compatible_runtimes = ["python3.11"]
  description         = "Python dependencies for Lambdas"
}

resource "aws_lambda_function" "ingestion" {
  function_name = "${var.project_name}-ingestion"
  filename      = data.archive_file.ingest_zip.output_path
  handler       = "ingestion.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout

  source_code_hash = filebase64sha256(data.archive_file.ingest_zip.output_path)

  environment {
    variables = {
        REDSHIFT_SECRET_ARN = aws_secretsmanager_secret.redshift.arn
        KINESIS_STREAM      = aws_kinesis_stream.video_events.name
        SQS_QUEUE_URL       = aws_sqs_queue.video_events.id
    }
  }

  tracing_config {
    mode = "Active" # Enables X-Ray
  }

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]
}

resource "aws_lambda_function" "processing" {
  function_name = "${var.project_name}-processing"
  handler       = "processing.lambda_handler"
  filename      = data.archive_file.processing_zip.output_path
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  memory_size   = var.lambda_memory
  timeout       = var.lambda_timeout

  source_code_hash = filebase64sha256(data.archive_file.processing_zip.output_path)

  environment {
    variables = {
        REDSHIFT_SECRET_ARN = aws_secretsmanager_secret.redshift.arn
        REDSHIFT_HOST       = aws_redshift_cluster.main.endpoint
        OPENSEARCH_ENDPOINT = aws_opensearch_domain.video_events.endpoint 
        KINESIS_STREAM      = aws_kinesis_stream.video_events.name
        SQS_QUEUE_URL       = aws_sqs_queue.video_events_dlq.id
    }
  }

  tracing_config {
    mode = "Active"
  }

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]

  dead_letter_config {
    target_arn = aws_sqs_queue.video_events_dlq.arn
  }
}

resource "aws_lambda_event_source_mapping" "processing_kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.video_events.arn
  function_name     = aws_lambda_function.processing.arn
  starting_position = "LATEST"
  batch_size        = 100
}

resource "aws_lambda_function" "query_lambda" {
  function_name = "${var.project_name}-query"
  filename      = data.archive_file.query_zip.output_path
  handler       = "query.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
        REDSHIFT_SECRET_ARN = aws_secretsmanager_secret.redshift.arn
        REDSHIFT_HOST       = aws_redshift_cluster.main.endpoint
        OPENSEARCH_ENDPOINT = aws_opensearch_domain.video_events.endpoint 
        SQS_QUEUE_URL       = aws_sqs_queue.video_events_dlq.id
    }
  }

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]

  dead_letter_config {
    target_arn = aws_sqs_queue.video_events_dlq.arn
  }
}

resource "aws_lambda_function" "start_glue" {
  function_name = "${var.project_name}-start-glue"
  filename      = data.archive_file.start_glue_zip.output_path
  handler       = "start_glue.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.rekognition_to_redshift.name
      SQS_QUEUE_URL = aws_sqs_queue.video_events_dlq.id
    }
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]

  dead_letter_config {
    target_arn = aws_sqs_queue.video_events_dlq.arn
  }
}

resource "aws_lambda_permission" "allow_s3_rekognition_raw" {
  statement_id  = "AllowExecutionFromS3RekognitionRaw"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_glue.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.rekognition_raw.arn
}

resource "aws_s3_bucket_notification" "rekognition_raw_trigger" {
  bucket = aws_s3_bucket.rekognition_raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.start_glue.arn
    events              = ["s3:ObjectCreated:*"]

    filter_prefix = "raw/rekognition/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_rekognition_raw
  ]
}

resource "aws_lambda_function" "index_faces" {
  function_name = "${var.project_name}-index-faces"
  filename      = data.archive_file.index_faces_zip.output_path
  handler       = "index_faces.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 30
  memory_size   = 256

  source_code_hash = filebase64sha256(data.archive_file.index_faces_zip.output_path)

  environment {
    variables = {
      COLLECTION_ID = aws_rekognition_collection.faces.id
      SQS_QUEUE_URL = aws_sqs_queue.video_events_dlq.id
    }
  }

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]

  tracing_config {
    mode = "Active"
  }


  dead_letter_config {
    target_arn = aws_sqs_queue.video_events_dlq.arn
  }
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.index_faces.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.face_images.arn
}