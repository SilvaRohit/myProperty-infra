# This SG is currently external to Terraform. Read it without changing rules.
# Its rule inventory is needed before adopting the SG itself in a later step.
data "aws_security_group" "existing_rds" {
  provider = aws.existing
  id       = "sg-0117f4f2a6cad457c"
}

# Preserve the actual six-subnet group, including public subnets, for import.
# A later, separate change can move RDS to a group containing private subnets.
resource "aws_db_subnet_group" "existing_property_db" {
  provider    = aws.existing
  name        = "default-vpc-0e4ef49349eaa8ec3"
  description = "Created from the RDS Management Console"
  subnet_ids  = concat(module.vpc.public_subnets, module.vpc.private_subnets)

  lifecycle {
    prevent_destroy = true
  }
}

# ADOPT THE EXISTING INSTANCE. Import before any normal apply.
# No password, password rotation, or database creation is configured here.
resource "aws_db_instance" "existing_property_db" {
  provider   = aws.existing
  identifier = "property-app-db"

  engine         = "postgres"
  engine_version = "18.3"
  instance_class = "db.t4g.micro"
  username       = "postgres"
  port           = 5432

  # DBName returned null. The SQL database you created manually remains in RDS;
  # it must NOT be inserted here as db_name during this import.

  allocated_storage     = 20
  max_allocated_storage = 1000
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id            = "arn:aws:kms:ap-southeast-7:147997138960:key/9509e285-3454-4138-b5b7-be6ff87d5e0f"

  db_subnet_group_name = aws_db_subnet_group.existing_property_db.name
  vpc_security_group_ids = [
    data.aws_security_group.existing_rds.id,
    aws_security_group.property_app.id,
  ]

  publicly_accessible = false
  multi_az            = false
  availability_zone   = "ap-southeast-7a"

  parameter_group_name = "default.postgres18"
  option_group_name    = "default:postgres-18"

  backup_retention_period    = 7
  backup_window              = "08:34-09:04"
  maintenance_window         = "fri:15:10-fri:15:40"
  auto_minor_version_upgrade = true
  deletion_protection        = true

  # Preserve current monitoring choices; do not enable new monitoring here.
  monitoring_interval          = 0
  performance_insights_enabled = true

  apply_immediately = false

  # Terraform-only deletion behavior; prevent_destroy blocks deletion first.
  skip_final_snapshot       = false
  final_snapshot_identifier = "property-app-db-final"
  copy_tags_to_snapshot     = true

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = (
        var.aws_account_id == "147997138960" &&
        var.aws_region == "ap-southeast-7"
      )
      error_message = "This import add-on is for account 147997138960 in ap-southeast-7 only."
    }
  }
}
