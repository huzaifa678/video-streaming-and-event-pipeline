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
