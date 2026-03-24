resource "aws_redshift_subnet_group" "main" {
  name       = "${var.project_name}-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-redshift-subnets"
  }
}

resource "aws_redshift_cluster" "main" {
  cluster_identifier = "${var.project_name}-cluster"
  node_type          = "ra3.xlplus"
  database_name      = "videoanalytics"
  master_username    = jsondecode(aws_secretsmanager_secret_version.redshift.secret_string)["username"]
  master_password    = jsondecode(aws_secretsmanager_secret_version.redshift.secret_string)["password"]
  cluster_type       = "single-node"
  skip_final_snapshot = true

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
