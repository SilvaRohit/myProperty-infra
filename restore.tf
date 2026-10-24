resource "aws_ssm_document" "property_restore_uploads" {
  name            = "${var.project_name}-${var.environment}-restore-uploads"
  document_type   = "Command"
  document_format = "JSON"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Restore an uploads backup into a new volume on a rebuilt host; retain the former volume"
    parameters = {
      BackupPrefix = {
        type              = "String"
        interpolationType = "ENV_VAR"
        allowedPattern    = "^s3://tecerotech-property-147997138960-backups/uploads/[A-Za-z0-9._/-]+$"
      }
    }
    mainSteps = [{
      action       = "aws:runShellScript"
      name         = "RestorePropertyUploads"
      precondition = { StringEquals = ["platformType", "Linux"] }
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [
          "set -eu",
          "test -f /opt/property-app-rebuild/completed",
          "exec /opt/property-app-deploy/restore-uploads.sh \"$SSM_BackupPrefix\""
        ]
      }
    }]
  })
}

output "uploads_restore_document" {
  value = aws_ssm_document.property_restore_uploads.name
}
