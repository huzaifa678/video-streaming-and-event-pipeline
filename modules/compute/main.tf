data "archive_file" "ingest_zip" {
  type        = "zip"
  source_file = "${var.source_root}/lambdas/ingestion.py"
  output_path = "${var.source_root}/builds/ingest.zip"
}

data "archive_file" "processing_zip" {
  type        = "zip"
  source_file = "${var.source_root}/lambdas/processing.py"
  output_path = "${var.source_root}/builds/processing.zip"
}

data "archive_file" "query_zip" {
  type        = "zip"
  source_file = "${var.source_root}/lambdas/query.py"
  output_path = "${var.source_root}/builds/query.zip"
}

data "archive_file" "index_faces_zip" {
  type        = "zip"
  source_file = "${var.source_root}/lambdas/index_faces.py"
  output_path = "${var.source_root}/builds/index_faces.zip"
}

data "archive_file" "firehose_transform_zip" {
  type        = "zip"
  source_file = "${var.source_root}/lambdas/firehose_transform.py"
  output_path = "${var.source_root}/builds/firehose_transform.zip"
}

data "archive_file" "python_lib_zip" {
  type        = "zip"
  source_dir  = "${var.source_root}/python_layer"
  output_path = "${var.source_root}/builds/python_lib.zip"
}

resource "aws_lambda_layer_version" "python_dependencies" {
  layer_name          = "python-dependencies"
  filename            = data.archive_file.python_lib_zip.output_path
  source_code_hash    = data.archive_file.python_lib_zip.output_base64sha256
  compatible_runtimes = ["python3.11"]
  description         = "Python dependencies for Lambdas"
}

resource "aws_rekognition_collection" "faces" {
  collection_id = "my-face-collection"
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
      REDSHIFT_SECRET_ARN = var.redshift_secret_arn
      KINESIS_STREAM      = var.kinesis_stream_name
      SQS_QUEUE_URL       = var.sqs_main_url
    }
  }

  tracing_config {
    mode = "Active"
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]
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
      REDSHIFT_SECRET_ARN = var.redshift_secret_arn
      REDSHIFT_HOST       = var.redshift_endpoint
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      KINESIS_STREAM      = var.kinesis_stream_name
      SQS_QUEUE_URL       = var.sqs_dlq_url
    }
  }

  tracing_config {
    mode = "Active"
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]

  dead_letter_config {
    target_arn = var.sqs_dlq_arn
  }
}

resource "aws_lambda_event_source_mapping" "processing_kinesis_trigger" {
  event_source_arn  = var.kinesis_stream_arn
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
      REDSHIFT_SECRET_ARN = var.redshift_secret_arn
      REDSHIFT_HOST       = var.redshift_endpoint
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      SQS_QUEUE_URL       = var.sqs_dlq_url
    }
  }

  tracing_config {
    mode = "Active"
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]

  dead_letter_config {
    target_arn = var.sqs_dlq_arn
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
      SQS_QUEUE_URL = var.sqs_dlq_url
    }
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = var.sqs_dlq_arn
  }
}

resource "aws_lambda_permission" "allow_s3_face_images" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.index_faces.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.face_images_bucket_arn
}

resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = var.face_images_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.index_faces.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_function.index_faces,
    aws_lambda_permission.allow_s3_face_images
  ]
}

resource "aws_lambda_function" "firehose_transform" {
  function_name = "${var.project_name}-firehose-transform"
  role          = aws_iam_role.lambda_exec.arn

  runtime = "python3.11"
  handler = "firehose_transform.lambda_handler"

  filename         = data.archive_file.firehose_transform_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.firehose_transform_zip.output_path)

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      SQS_QUEUE_URL = var.sqs_dlq_url
    }
  }

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = var.sqs_dlq_arn
  }

  layers = [aws_lambda_layer_version.python_dependencies.arn]
}
