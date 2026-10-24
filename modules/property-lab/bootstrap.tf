locals {
  bootstrap_files = {
    "empty-db.mjs"                    = file("${path.module}/../../bootstrap/assets/empty-db.mjs")
    "bootstrap-ec2.sh"                = file("${path.module}/../../bootstrap/bootstrap-ec2.sh")
    "runtime.py"                      = file("${path.module}/../../bootstrap/runtime.py")
    "refresh-env.sh"                  = file("${path.module}/../../bootstrap/refresh-env.sh")
    "restore-uploads.sh"              = file("${path.module}/../../bootstrap/restore-uploads.sh")
    "deploy.sh"                       = file("${path.module}/../../bootstrap/assets/deploy.sh")
    "backup-uploads.sh"               = file("${path.module}/../../bootstrap/assets/backup-uploads.sh")
    "property-uploads-backup.service" = file("${path.module}/../../bootstrap/assets/property-uploads-backup.service")
    "cloudwatch-agent.json"           = file("${path.module}/../../bootstrap/assets/cloudwatch-agent.json")
    "property-uploads-backup.timer"   = file("${path.module}/../../bootstrap/assets/property-uploads-backup.timer")
    "compose.yml"                     = file("${path.module}/../../bootstrap/assets/compose.yml")
    "check-db.mjs"                    = file("${path.module}/../../bootstrap/assets/check-db.mjs")
  }
  user_data = var.rebuild_mode == "existing" ? null : base64gzip(templatefile("${path.module}/../../bootstrap/user-data.sh.tftpl", {
    payload = base64gzip(jsonencode({
      files = local.bootstrap_files
      config = {
        region                    = var.aws_region
        secret_arn                = var.application_secret_arn
        database_host             = aws_db_instance.existing_property_db.address
        image_uri                 = var.initial_image_uri
        initialize_empty_database = var.rebuild_mode == "fresh"
        uploads_prefix            = var.uploads_restore_s3_prefix
        enable_https              = var.enable_https
        enable_backups            = var.enable_backups
      }
    }))
  }))
}
