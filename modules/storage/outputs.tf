output "analysis_results_bucket_id" {
  value = aws_s3_bucket.analysis_results.id
}

output "analysis_results_bucket_arn" {
  value = aws_s3_bucket.analysis_results.arn
}

output "analysis_results_bucket_name" {
  value = aws_s3_bucket.analysis_results.bucket
}

output "rekognition_raw_bucket_id" {
  value = aws_s3_bucket.rekognition_raw.id
}

output "rekognition_raw_bucket_arn" {
  value = aws_s3_bucket.rekognition_raw.arn
}

output "rekognition_raw_bucket_name" {
  value = aws_s3_bucket.rekognition_raw.bucket
}

output "analytics_bucket_arn" {
  value = aws_s3_bucket.analytics.arn
}

output "face_images_bucket_arn" {
  value = aws_s3_bucket.face_images.arn
}

output "face_images_bucket_id" {
  value = aws_s3_bucket.face_images.id
}

output "redshift_secret_arn" {
  value = aws_secretsmanager_secret.redshift.arn
}

output "redshift_secret_string" {
  value     = aws_secretsmanager_secret_version.redshift.secret_string
  sensitive = true
}

output "opensearch_secret_string" {
  value     = aws_secretsmanager_secret_version.opensearch.secret_string
  sensitive = true
}
