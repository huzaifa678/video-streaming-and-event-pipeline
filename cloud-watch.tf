resource "aws_cloudwatch_log_group" "lambda_ingestion_logs" {
  name              = "/aws/lambda/${var.project_name}-ingestion"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_processing_logs" {
  name              = "/aws/lambda/${var.project_name}-processing"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_glue_logs" {
  name              = "/aws/lambda/${var.project_name}-glue"
  retention_in_days = 30
}

resource "aws_cloudwatch_metric_alarm" "sqs_dlq_alarm" {
  alarm_name          = "${var.project_name}-sqs-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions = {
    QueueName = aws_sqs_queue.video_events_dlq.name
  }

  alarm_description = "Triggered when there are messages in SQS DLQ"
}