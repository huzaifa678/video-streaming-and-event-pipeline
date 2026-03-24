resource "aws_secretsmanager_secret" "redshift" {
  name = "${var.project_name}-redshift-credentials"
}

resource "aws_secretsmanager_secret_version" "redshift" {
  secret_id     = aws_secretsmanager_secret.redshift.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.redshift.result
  })
}

resource "random_password" "redshift" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+"
}

resource "aws_secretsmanager_secret" "opensearch" {
  name = "${var.project_name}-opensearch-credentials"
}

resource "random_password" "opensearch" {
  length           = 16
  special          = true
  override_special = "!@#%^&*()-_=+"
}

resource "aws_secretsmanager_secret_version" "opensearch" {
  secret_id     = aws_secretsmanager_secret.opensearch.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.opensearch.result
  })
}