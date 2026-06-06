output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "kms_key_arn" {
  value = aws_kms_key.video_stream_key.arn
}

output "kms_key_id" {
  value = aws_kms_key.video_stream_key.id
}
