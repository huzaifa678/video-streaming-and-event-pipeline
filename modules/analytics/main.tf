resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name = "${var.project_name}-redshift-subnets"
  }
}

resource "aws_redshift_cluster" "main" {
  cluster_identifier        = "${var.project_name}-cluster"
  node_type                 = "ra3.xlplus"
  database_name             = "videoanalytics"
  master_username           = jsondecode(var.redshift_secret_string)["username"]
  master_password           = jsondecode(var.redshift_secret_string)["password"]
  cluster_type              = "single-node"
  skip_final_snapshot       = true
  cluster_subnet_group_name = aws_redshift_subnet_group.main.name
}

resource "null_resource" "create_video_events_table" {
  depends_on = [aws_redshift_cluster.main]

  provisioner "local-exec" {
    command = <<EOT
aws redshift-data execute-statement \
    --cluster-identifier ${aws_redshift_cluster.main.cluster_identifier} \
    --database videoanalytics \
    --db-user ${aws_redshift_cluster.main.master_username} \
    --sql "CREATE TABLE IF NOT EXISTS video_events (video_id VARCHAR(100) NOT NULL, timestamp TIMESTAMP NOT NULL, metadata VARCHAR(65535));" \
    --region ${var.aws_region}
EOT
  }
}

resource "aws_opensearch_domain" "video_events" {
  domain_name    = "${var.project_name}-video-events"
  engine_version = "OpenSearch_2.9"

  cluster_config {
    instance_type          = "t3.small.search"
    instance_count         = 2
    zone_awareness_enabled = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = var.kms_key_arn
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = jsondecode(var.opensearch_secret_string)["username"]
      master_user_password = jsondecode(var.opensearch_secret_string)["password"]
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}
