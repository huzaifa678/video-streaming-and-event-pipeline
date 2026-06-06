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

data "archive_file" "index_faces_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/index_faces.py"
  output_path = "${path.module}/builds/index_faces.zip"
}

data "archive_file" "firehose_transform_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/firehose_transform.py"
  output_path = "${path.module}/builds/firehose_transform.zip"
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

resource "aws_lambda_permission" "allow_s3_face_images" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.index_faces.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.face_images.arn
}

resource "aws_lambda_function" "firehose_transform" {
  function_name = "${var.project_name}-firehose-transform"
  role          = aws_iam_role.lambda_exec.arn

  runtime = "python3.11"
  handler = "firehose_transform.lambda_handler"

  filename      = data.archive_file.firehose_transform_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.firehose_transform_zip.output_path)

  timeout = 10
  memory_size = 128

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.video_events_dlq.id
    }
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.video_events_dlq.arn
  }

  layers = [
    aws_lambda_layer_version.python_dependencies.arn
  ]
}

resource "aws_lambda_permission" "allow_firehose_invoke" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.firehose_transform.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.rekognition_to_s3.arn
}
