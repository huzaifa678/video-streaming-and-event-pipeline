resource "aws_s3_bucket" "analysis_results" {
  bucket        = "${var.project_name}-video-results-storage"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "rekognition_raw" {
  bucket        = "${var.project_name}-rekognition-raw"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "analytics" {
  bucket        = "${var.project_name}-analytics"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket" "face_images" {
  bucket        = "${var.project_name}-face-image"
  force_destroy = true

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}

resource "aws_s3_bucket_notification" "rekognition_eventbridge" {
  bucket      = aws_s3_bucket.rekognition_raw.id
  eventbridge = true
}

resource "aws_secretsmanager_secret" "redshift" {
  name = "${var.project_name}-redshift-credentials"
}

resource "random_password" "redshift" {
  length           = 16
  numeric          = true
  upper            = true
  lower            = true
  min_numeric      = 1
  min_upper        = 1
  min_lower        = 1
  special          = true
  override_special = "!#$%^&*()-_=+"
}

resource "aws_secretsmanager_secret_version" "redshift" {
  secret_id = aws_secretsmanager_secret.redshift.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.redshift.result
  })
}

resource "aws_secretsmanager_secret" "opensearch" {
  name = "${var.project_name}-opensearch-credentials"
}

resource "random_password" "opensearch" {
  length           = 16
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  special          = true
  override_special = "!@#%^&*()-_=+"
}

resource "aws_secretsmanager_secret_version" "opensearch" {
  secret_id = aws_secretsmanager_secret.opensearch.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.opensearch.result
  })
}
