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
