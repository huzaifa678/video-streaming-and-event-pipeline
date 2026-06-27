variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "kvs_arn" {
  type = string
}

variable "video_events_kinesis_arn" {
  type = string
}

variable "analytics_bucket_arn" {
  type = string
}

variable "analysis_results_bucket_arn" {
  type = string
}

variable "rekognition_raw_bucket_arn" {
  type = string
}

variable "rekognition_collection_id" {
  type = string
}

variable "firehose_transform_function_name" {
  type = string
}

variable "firehose_transform_arn" {
  type = string
}

variable "sqs_dlq_arn" {
  type = string
}

variable "sqs_dlq_url" {
  type = string
}

variable "healer_schedule" {
  description = "EventBridge schedule expression for the KVS healer"
  type        = string
  default     = "rate(2 minutes)"
}
