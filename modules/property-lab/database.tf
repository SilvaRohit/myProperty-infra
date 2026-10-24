resource "aws_db_subnet_group" "existing_property_db" {
  provider    = aws.existing
  name        = var.rebuild_mode == "existing" ? "default-vpc-0e4ef49349eaa8ec3" : "${var.prefix}-db"
  description = var.rebuild_mode == "existing" ? "Created from the RDS Management Console" : "Private database subnets for the property lab"
  subnet_ids  = var.rebuild_mode == "existing" ? concat(module.vpc.public_subnets, module.vpc.private_subnets) : module.vpc.private_subnets
}

# Existing mode preserves the imported database. Fresh/restore use a write-only
# password from an ephemeral secret read; credentials are not written to state.
resource "aws_db_instance" "existing_property_db" {
  provider   = aws.existing
  identifier = var.database_identifier

  engine              = "postgres"
  engine_version      = var.rebuild_mode == "restore" ? null : var.database_engine_version
  instance_class      = "db.t4g.micro"
  username            = "postgres"
  db_name             = var.rebuild_mode == "fresh" ? "propertyapp" : null
  snapshot_identifier = var.rebuild_mode == "restore" ? var.database_snapshot_identifier : null
  password_wo         = var.rebuild_mode == "existing" ? null : local.database_password
  password_wo_version = var.rebuild_mode == "existing" ? null : var.database_password_version
  port                = 5432

  # DBName returned null. The SQL database you created manually remains in RDS;
  # it must NOT be inserted here as db_name during this import.

  allocated_storage     = var.rebuild_mode == "restore" ? null : 20
  max_allocated_storage = 1000
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id            = var.rebuild_mode == "existing" ? "arn:aws:kms:ap-southeast-7:147997138960:key/9509e285-3454-4138-b5b7-be6ff87d5e0f" : null

  db_subnet_group_name = aws_db_subnet_group.existing_property_db.name
  vpc_security_group_ids = [
    aws_security_group.database.id,
  ]

  publicly_accessible = false
  multi_az            = false
  availability_zone   = var.availability_zones[0]

  parameter_group_name = "default.postgres18"
  option_group_name    = "default:postgres-18"

  backup_retention_period    = 7
  backup_window              = "08:34-09:04"
  maintenance_window         = "fri:15:10-fri:15:40"
  auto_minor_version_upgrade = true
  deletion_protection        = var.database_deletion_protection

  # Preserve current monitoring choices; do not enable new monitoring here.
  monitoring_interval          = 0
  performance_insights_enabled = true

  apply_immediately = var.rebuild_mode != "existing"

  depends_on = [aws_security_group_rule.database_from_app]

  # Final snapshots are retained for primary lab teardown; temporary rehearsals skip them.
  skip_final_snapshot       = !var.take_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
  copy_tags_to_snapshot     = true

  lifecycle {
    precondition {
      condition     = var.rebuild_mode != "restore" || var.database_snapshot_identifier != ""
      error_message = "Restore mode requires an exact snapshot identifier."
    }
    precondition {
      condition     = var.rebuild_mode == "existing" || var.initial_image_uri != ""
      error_message = "A fresh host requires an immutable initial_image_uri."
    }
    precondition {
      condition = (
        var.aws_account_id == "147997138960" &&
        var.aws_region == "ap-southeast-7"
      )
      error_message = "This import add-on is for account 147997138960 in ap-southeast-7 only."
    }
  }
}
