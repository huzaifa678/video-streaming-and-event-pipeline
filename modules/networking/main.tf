data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Private subnets need egress to AWS APIs (Secrets Manager, STS, Glue, etc.)
  # Single NAT gateway is cheaper than per-AZ.
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}

# S3 Gateway endpoint — required by Glue's VPC connection validator and
# also avoids NAT cost for S3 traffic (reads/writes from the job).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name = "${var.project_name}-s3-gateway"
  }
}

resource "aws_kms_key" "video_stream_key" {
  description             = "KMS key for encrypting video streams in ${var.project_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "video_stream_alias" {
  name          = "alias/${var.project_name}-video-stream"
  target_key_id = aws_kms_key.video_stream_key.id
}
