resource "aws_opensearch_domain" "video_events" {
  domain_name    = "${var.project_name}-video-events"
  engine_version = "OpenSearch_2.9"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 2
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
    kms_key_id = aws_kms_key.video_stream_key.arn
  }

  domain_endpoint_options {
    enforce_https      = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                       = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = jsondecode(aws_secretsmanager_secret_version.opensearch.secret_string)["username"]
      master_user_password = jsondecode(aws_secretsmanager_secret_version.opensearch.secret_string)["password"]
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.env
  }
}