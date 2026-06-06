resource "aws_sqs_queue" "video_events_dlq" {
  name                      = "${var.project_name}-events-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "video_events" {
  name                       = "${var.project_name}-events-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_events_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_kinesis_stream" "video_events" {
  name             = "${var.project_name}-events"
  shard_count      = 1
  retention_period = 24
}

resource "aws_kinesis_video_stream" "video_stream" {
  name                    = "${var.project_name}-video-stream"
  data_retention_in_hours = 24
  media_type              = "video/h264"
  kms_key_id              = var.kms_key_id

  tags = {
    Environment = var.env
    Project     = var.project_name
  }
}
