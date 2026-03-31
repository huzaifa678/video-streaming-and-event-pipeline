variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "video-analytics"
}

variable "env" {
    type = string
    default = "dev"
}

variable "lambda_memory" {
  type    = number
  default = 256
}

variable "lambda_timeout" {
  type    = number
  default = 10
}

variable "bucket_name_remote" {
  type = string
  default = "video-ml-pipeline-terraform-state-ec371a2a"
}

variable "bucket_key_name" {
  type = string
  default = "video-pipeline-arch/terraform.tfstate"
}