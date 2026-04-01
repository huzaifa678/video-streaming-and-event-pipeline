resource "aws_kinesis_firehose_delivery_stream" "video_events_to_s3" {
  name        = "${var.project_name}-to-s3"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.video_events.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.analytics.arn
    prefix = "bronze/events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    compression_format = "GZIP"
    buffering_size     = 128
    buffering_interval = 60
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
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.rekognition_raw.arn
    buffering_size     = 128
    buffering_interval = 60
    error_output_prefix = "errors/!{firehose:error-output-type}/"
    prefix = "raw/rekognition/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    
    processing_configuration {
      enabled = "true"

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.firehose_transform.arn
        }
      }
    }
  }
}