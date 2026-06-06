output "api_gateway_endpoint" {
  description = "HTTP endpoint of the API Gateway"
  value       = module.api.invoke_url
}

output "kinesis_video_stream_name" {
  value = module.messaging.kvs_name
}

output "kinesis_video_stream_arn" {
  value = module.messaging.kvs_arn
}

output "kinesis_data_stream_name" {
  value = module.messaging.kinesis_stream_name
}

output "kinesis_data_stream_arn" {
  value = module.messaging.kinesis_stream_arn
}

output "sqs_queue_url" {
  value = module.messaging.sqs_main_url
}

output "sqs_dlq_url" {
  value = module.messaging.sqs_dlq_id
}

output "lambda_ingestion_name" {
  value = module.compute.ingestion_function_name
}

output "lambda_processing_name" {
  value = module.compute.processing_function_name
}

output "lambda_query_name" {
  value = module.compute.query_function_name
}

output "redshift_endpoint" {
  value = module.analytics.redshift_endpoint
}

output "redshift_db_name" {
  value = module.analytics.redshift_database_name
}

output "opensearch_endpoint" {
  value = module.analytics.opensearch_endpoint
}

output "glue_orchestrator_state_machine_arn" {
  value = module.etl.state_machine_arn
}
