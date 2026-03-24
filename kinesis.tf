resource "aws_kinesis_stream" "video_events" {
  name             = "${var.project_name}-events"
  shard_count      = 1
  retention_period = 24
}

resource "aws_kinesis_video_stream" "video_stream" {
  name                     = "${var.project_name}-video-stream"
  data_retention_in_hours  = 24
  media_type               = "video/h264"
  kms_key_id               = aws_kms_key.video_stream_key.arn

  tags = {
    Environment = var.env
    Project     = var.project_name
  }
}