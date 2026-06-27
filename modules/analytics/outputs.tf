output "redshift_endpoint" {
  value = aws_redshift_cluster.main.endpoint
}

output "redshift_database_name" {
  value = aws_redshift_cluster.main.database_name
}

output "opensearch_endpoint" {
  value = aws_opensearch_domain.video_events.endpoint
}

output "opensearch_arn" {
  value = aws_opensearch_domain.video_events.arn
}

output "redshift_security_group_id" {
  value = aws_redshift_cluster.main.vpc_security_group_ids != null ? tolist(aws_redshift_cluster.main.vpc_security_group_ids)[0] : ""
}
