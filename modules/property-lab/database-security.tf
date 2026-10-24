resource "aws_security_group" "database" {
  provider    = aws.existing
  name        = var.rebuild_mode == "existing" ? "rds-ec2-1" : "${var.prefix}-database"
  description = var.rebuild_mode == "existing" ? "Security group attached to property-app-db to allow EC2 instances with specific security groups attached to connect to the database. Modification could lead to connection loss." : "PostgreSQL from the property application security group"
  vpc_id      = module.vpc.vpc_id
  # Rules stay separate. Importing the group does not replace its existing rules.
}

resource "aws_security_group_rule" "database_from_app" {
  provider                 = aws.existing
  type                     = "ingress"
  security_group_id        = aws_security_group.database.id
  source_security_group_id = aws_security_group.property_app.id
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  lifecycle { ignore_changes = [description] }
}
