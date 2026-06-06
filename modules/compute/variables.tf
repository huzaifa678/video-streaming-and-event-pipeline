variable "project_name" {
  type = string
}

variable "lambda_memory" {
  type = number
}

variable "lambda_timeout" {
  type = number
}

variable "source_root" {
  description = "Path to repo root where lambdas/, builds/, python_layer/ live"
  type        = string
}

variable "redshift_secret_arn" {
  type = string
}

variable "redshift_endpoint" {
  type = string
}

variable "opensearch_endpoint" {
  type = string
}

variable "opensearch_arn" {
  type = string
}

variable "kinesis_stream_name" {
  type = string
}

variable "kinesis_stream_arn" {
  type = string
}

variable "sqs_main_url" {
  type = string
}

variable "sqs_main_arn" {
  type = string
}

variable "sqs_dlq_url" {
  type = string
}

variable "sqs_dlq_arn" {
  type = string
}

variable "kvs_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "analysis_results_bucket_arn" {
  type = string
}

variable "face_images_bucket_arn" {
  type = string
}

variable "face_images_bucket_id" {
  type = string
}
