output "sqs_main_url" {
  value = aws_sqs_queue.video_events.id
}

output "sqs_main_arn" {
  value = aws_sqs_queue.video_events.arn
}

output "sqs_dlq_url" {
  value = aws_sqs_queue.video_events_dlq.url
}

output "sqs_dlq_id" {
  value = aws_sqs_queue.video_events_dlq.id
}

output "sqs_dlq_arn" {
  value = aws_sqs_queue.video_events_dlq.arn
}

output "sqs_dlq_name" {
  value = aws_sqs_queue.video_events_dlq.name
}

output "kinesis_stream_name" {
  value = aws_kinesis_stream.video_events.name
}

output "kinesis_stream_arn" {
  value = aws_kinesis_stream.video_events.arn
}

output "kvs_name" {
  value = aws_kinesis_video_stream.video_stream.name
}

output "kvs_arn" {
  value = aws_kinesis_video_stream.video_stream.arn
}
