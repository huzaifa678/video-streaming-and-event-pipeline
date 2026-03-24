terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.10.0"
    }
  }

  backend "s3" {
    bucket         = "video-ml-pipeline-terraform-state-ec371a2a"
    key            = "video-pipeline-arch/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = true
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}