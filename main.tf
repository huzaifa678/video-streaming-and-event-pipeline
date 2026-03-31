terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.10.0"
    }
  }

  backend "s3" {
    bucket         = var.bucket_name_remote
    key            = var.bucket_key_name
    region         = var.aws_region
    use_lockfile = true
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}