variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "redshift_secret_string" {
  type      = string
  sensitive = true
}

variable "opensearch_secret_string" {
  type      = string
  sensitive = true
}

variable "kms_key_arn" {
  type = string
}
