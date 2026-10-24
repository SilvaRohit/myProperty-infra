module "lab" {
  count                        = var.lab_enabled ? 1 : 0
  source                       = "./modules/property-lab"
  providers                    = { aws = aws, aws.existing = aws.existing }
  aws_account_id               = var.aws_account_id
  aws_region                   = var.aws_region
  prefix                       = "${var.project_name}-${var.environment}"
  vpc_name                     = var.vpc_name
  vpc_cidr                     = var.vpc_cidr
  availability_zones           = var.availability_zones
  public_subnet_cidrs          = var.public_subnet_cidrs
  private_subnet_cidrs         = var.private_subnet_cidrs
  ami_id                       = data.aws_ami.ubuntu.id
  instance_type                = var.instance_type
  instance_name                = var.instance_name
  key_pair_name                = var.key_pair_name
  instance_profile_name        = aws_iam_instance_profile.property_deploy.name
  rebuild_mode                 = var.rebuild_mode
  database_identifier          = "property-app-db"
  database_engine_version      = "18.3"
  database_snapshot_identifier = var.database_snapshot_identifier
  database_password_version    = var.database_password_version
  database_deletion_protection = var.database_deletion_protection
  final_snapshot_identifier    = var.final_snapshot_identifier
  elastic_ip_allocation_id     = aws_eip.existing_property_app.id
  application_secret_arn       = aws_secretsmanager_secret.property_config.arn
  initial_image_uri            = var.initial_image_uri
  uploads_restore_s3_prefix    = var.uploads_restore_s3_prefix
  enable_https                 = true
  take_final_snapshot          = true
  enable_backups               = true
  depends_on = [
    aws_iam_role_policy_attachment.property_deploy_ssm_core,
    aws_iam_role_policy.property_deploy_ecr_pull,
    aws_iam_role_policy.property_config_read,
    aws_iam_role_policy.property_uploads_backup,
    aws_iam_role_policy.property_cloudwatch_metrics,
    aws_iam_role_policy.property_application_logs,
  ]
}

module "rehearsal" {
  count                        = var.rehearsal_enabled ? 1 : 0
  source                       = "./modules/property-lab"
  providers                    = { aws = aws, aws.existing = aws.existing }
  aws_account_id               = var.aws_account_id
  aws_region                   = var.aws_region
  prefix                       = "${var.project_name}-${var.environment}-rehearsal"
  vpc_name                     = "property-rebuild-rehearsal"
  vpc_cidr                     = "10.20.0.0/16"
  availability_zones           = var.availability_zones
  public_subnet_cidrs          = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  private_subnet_cidrs         = ["10.20.100.0/24", "10.20.101.0/24", "10.20.102.0/24"]
  ami_id                       = data.aws_ami.ubuntu.id
  instance_type                = var.instance_type
  instance_name                = "property-rebuild-rehearsal"
  key_pair_name                = var.key_pair_name
  instance_profile_name        = aws_iam_instance_profile.property_deploy.name
  rebuild_mode                 = var.rehearsal_snapshot_identifier == "" ? "fresh" : "restore"
  database_identifier          = "property-app-dev-rehearsal"
  database_engine_version      = "18.3"
  database_snapshot_identifier = var.rehearsal_snapshot_identifier
  database_password_version    = var.database_password_version
  database_deletion_protection = false
  final_snapshot_identifier    = "property-app-rehearsal-final"
  elastic_ip_allocation_id     = null
  application_secret_arn       = aws_secretsmanager_secret.property_config.arn
  initial_image_uri            = var.initial_image_uri
  uploads_restore_s3_prefix    = var.rehearsal_uploads_s3_prefix
  enable_https                 = false
  take_final_snapshot          = false
  enable_backups               = false
  depends_on = [
    aws_iam_role_policy_attachment.property_deploy_ssm_core,
    aws_iam_role_policy.property_deploy_ecr_pull,
    aws_iam_role_policy.property_config_read,
    aws_iam_role_policy.property_uploads_backup,
    aws_iam_role_policy.property_cloudwatch_metrics,
    aws_iam_role_policy.property_application_logs,
  ]
}
