output "api_gateway_endpoint" {
  description = "HTTP endpoint of the API Gateway"
  value       = aws_apigatewayv2_stage.stage.invoke_url
}

output "kinesis_video_stream_name" {
  description = "Name of the Kinesis Video Stream"
  value       = aws_kinesis_video_stream.video_stream.name
}

output "kinesis_video_stream_arn" {
  description = "ARN of the Kinesis Video Stream"
  value       = aws_kinesis_video_stream.video_stream.arn
}

output "kinesis_data_stream_name" {
  description = "Name of the Kinesis Data Stream"
  value       = aws_kinesis_stream.video_events.name
}

output "kinesis_data_stream_arn" {
  description = "ARN of the Kinesis Data Stream"
  value       = aws_kinesis_stream.video_events.arn
}

output "sqs_queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.video_events.id
}

output "sqs_dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.video_events_dlq.id
}

# Lambda Functions
output "lambda_ingestion_name" {
  description = "Ingestion Lambda name"
  value       = aws_lambda_function.ingestion.function_name
}

output "lambda_processing_name" {
  description = "Processing Lambda name"
  value       = aws_lambda_function.processing.function_name
}

output "lambda_glue_start_name" {
  description = "Glue Start Lambda name"
  value       = aws_lambda_function.start_glue.function_name
}

output "lambda_query_name" {
  description = "Query Lambda name"
  value       = aws_lambda_function.query_lambda.function_name
}

# Redshift
output "redshift_endpoint" {
  description = "Redshift cluster endpoint"
  value       = aws_redshift_cluster.main.endpoint
}

output "redshift_db_name" {
  description = "Redshift database name"
  value       = aws_redshift_cluster.main.database_name
}

output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = aws_opensearch_domain.video_events.endpoint
}

output "firehose_s3_bucket" {
  description = "S3 bucket used by Firehose for storing events"
  value       = aws_s3_bucket.analysis_results.bucket
}