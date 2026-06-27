resource "aws_kinesis_stream" "rekognition_output" {
  name             = "${var.project_name}-rekognition-results"
  shard_count      = var.env == "dev" ? 1 : 2
  retention_period = 24
}

resource "aws_rekognition_stream_processor" "video_processor" {
  name     = "${var.project_name}-video-processor"
  role_arn = aws_iam_role.rekognition_role.arn

  depends_on = [aws_iam_role_policy.rekognition_kinesis_access]

  input {
    kinesis_video_stream {
      arn = var.kvs_arn
    }
  }

  output {
    kinesis_data_stream {
      arn = aws_kinesis_stream.rekognition_output.arn
    }
  }

  settings {
    face_search {
      collection_id        = var.rekognition_collection_id
      face_match_threshold = 85.0
    }
  }

  data_sharing_preference {
    opt_in = false
  }

  # handled by github actions pipeline
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [data_sharing_preference]
  }
}

resource "aws_kinesis_firehose_delivery_stream" "video_events_to_s3" {
  name        = "${var.project_name}-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = var.video_events_kinesis_arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = var.analytics_bucket_arn
    prefix              = "bronze/events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    compression_format  = "GZIP"
    buffering_size      = 128
    buffering_interval  = 60
    error_output_prefix = "errors/!{firehose:error-output-type}/"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "rekognition_to_s3" {
  name        = "${var.project_name}-rekognition-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.rekognition_output.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = var.rekognition_raw_bucket_arn
    buffering_size      = 128
    buffering_interval  = 60
    error_output_prefix = "errors/!{firehose:error-output-type}/"
    prefix              = "raw/rekognition/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = var.firehose_transform_arn
        }
      }
    }
  }
}

resource "aws_lambda_permission" "allow_firehose_invoke" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = var.firehose_transform_function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = aws_kinesis_firehose_delivery_stream.rekognition_to_s3.arn
}
