# Add to the existing Terraform root. Copy rollback-runtime/ beside this file.
# Reuses the existing GitHub OIDC role, EC2 instance and EC2 permissions.

locals {
  property_rollback_button_script = replace(
    file("${path.module}/rollback-runtime/rollback-button.sh"),
    "__DEPLOY_SCRIPT_BASE64__",
    filebase64("${path.module}/rollback-runtime/deploy.sh")
  )
}

resource "aws_ssm_document" "property_rollback" {
  name            = "${var.project_name}-${var.environment}-rollback-property-app"
  document_type   = "Command"
  document_format = "JSON"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Roll back the existing property app once per GitHub workflow run"
    parameters = {
      RequestId = {
        type              = "String"
        description       = "GitHub workflow run ID; unchanged when a failed run is retried"
        interpolationType = "ENV_VAR"
        allowedPattern    = "^[0-9]+$"
      }
    }
    mainSteps = [{
      action       = "aws:runShellScript"
      name         = "RollbackPropertyApp"
      precondition = { StringEquals = ["platformType", "Linux"] }
      inputs = {
        timeoutSeconds = "1800"
        runCommand = [
          "set -eu",
          "if [ -f /opt/property-app-rebuild/started ]; then timeout 600 cloud-init status --wait; test -f /opt/property-app-rebuild/completed; fi",
          "/opt/property-app-deploy/refresh-env.sh",
          "printf '%s' '${base64encode(local.property_rollback_button_script)}' | base64 --decode | bash"
        ]
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_property_rollback" {
  name = "rollback-property-app-through-ssm"
  role = aws_iam_role.github_ecr_push.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:SendCommand"
      Resource = concat([aws_ssm_document.property_rollback.arn], [for lab in module.lab : lab.instance_arn])
    }]
  })
}
