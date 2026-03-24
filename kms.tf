resource "aws_kms_key" "video_stream_key" {
  description             = "KMS key for encrypting video streams in ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "video_stream_alias" {
  name          = "alias/${var.project_name}-video-stream"
  target_key_id = aws_kms_key.video_stream_key.id
}