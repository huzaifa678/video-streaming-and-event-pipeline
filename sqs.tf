resource "aws_sqs_queue" "video_events_dlq" {
  name                      = "${var.project_name}-events-dlq"
  message_retention_seconds  = 1209600  # 14 days
}

resource "aws_sqs_queue" "video_events" {
  name                      = "${var.project_name}-events-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_events_dlq.arn
    maxReceiveCount     = 5
  })
}