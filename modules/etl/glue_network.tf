# Security group attached to the Glue NETWORK connection. Self-referencing
# ingress is required by AWS Glue. Egress is wide open so the worker can
# reach Redshift, secretsmanager, and S3 endpoints.
resource "aws_security_group" "glue" {
  name        = "${var.project_name}-glue-sg"
  description = "Glue worker SG for VPC connection"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "glue_self_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.glue.id
  self              = true
}

resource "aws_security_group_rule" "glue_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.glue.id
}

# Allow Glue SG -> Redshift SG on 5439
resource "aws_security_group_rule" "redshift_from_glue" {
  type                     = "ingress"
  from_port                = 5439
  to_port                  = 5439
  protocol                 = "tcp"
  security_group_id        = var.redshift_security_group_id
  source_security_group_id = aws_security_group.glue.id
}

# NETWORK-type connection: Glue uses the subnet/SG to attach the worker
# inside the VPC so it can resolve and reach the private Redshift endpoint.
resource "aws_glue_connection" "redshift_vpc" {
  name            = "${var.project_name}-glue-redshift-vpc"
  connection_type = "NETWORK"

  physical_connection_requirements {
    subnet_id              = var.private_subnet_id
    security_group_id_list = [aws_security_group.glue.id]
    availability_zone      = data.aws_subnet.private.availability_zone
  }
}

data "aws_subnet" "private" {
  id = var.private_subnet_id
}
