variable "project_name" {
  type = string
}

variable "source_root" {
  type = string
}

variable "analysis_results_bucket_id" {
  type = string
}

variable "analysis_results_bucket_arn" {
  type = string
}

variable "analysis_results_bucket_name" {
  type = string
}

variable "rekognition_raw_bucket_arn" {
  type = string
}

variable "rekognition_raw_bucket_name" {
  type = string
}

variable "redshift_endpoint" {
  type = string
}

variable "redshift_secret_arn" {
  type = string
}

variable "sqs_dlq_arn" {
  type = string
}

variable "sqs_dlq_url" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_id" {
  description = "Subnet used by the Glue connection (must reach Redshift)"
  type        = string
}

variable "redshift_security_group_id" {
  type = string
}
