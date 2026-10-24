# Add alongside the existing github_actions.tf and compute.tf.
# This extends aws_iam_role.github_ecr_push; it does not create another OIDC provider.

resource "aws_iam_role" "property_deploy_ec2" {
  count = var.deployment_existing_ec2_role_name == "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-ec2-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

locals {
  property_deploy_ec2_role_name = var.deployment_existing_ec2_role_name != "" ? var.deployment_existing_ec2_role_name : aws_iam_role.property_deploy_ec2[0].name
}

resource "aws_iam_instance_profile" "property_deploy" {
  name = "${var.project_name}-${var.environment}-ec2-deploy"
  role = local.property_deploy_ec2_role_name
}

resource "aws_iam_role_policy_attachment" "property_deploy_ssm_core" {
  role       = local.property_deploy_ec2_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "property_deploy_ecr_pull" {
  name = "property-app-deploy-ecr-pull"
  role = local.property_deploy_ec2_role_name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = aws_ecr_repository.property_app.arn
      }
    ]
  })
}

resource "aws_ssm_document" "property_deploy" {
  name            = "${var.project_name}-${var.environment}-deploy-property-app"
  document_type   = "Command"
  document_format = "JSON"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy a versioned property-app-dev image using the installed EC2 deployment script"
    parameters = {
      ImageUri = {
        type              = "String"
        description       = "Exact image URI published by the GitHub workflow"
        interpolationType = "ENV_VAR"
        allowedPattern    = "^147997138960\\.dkr\\.ecr\\.ap-southeast-7\\.amazonaws\\.com/property-app-dev:sha-[0-9a-f]{40}-run-[0-9]+-[0-9]+$"
      }
    }
    mainSteps = [{
      action       = "aws:runShellScript"
      name         = "DeployPropertyApp"
      precondition = { StringEquals = ["platformType", "Linux"] }
      inputs = {
        timeoutSeconds = "1500"
        runCommand = [
          "set -eu",
          "if [ -f /opt/property-app-rebuild/started ]; then timeout 600 cloud-init status --wait; test -f /opt/property-app-rebuild/completed; fi",
          "/opt/property-app-deploy/refresh-env.sh",
          "exec /opt/property-app-deploy/deploy.sh \"$SSM_ImageUri\""
        ]
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_property_deploy" {
  name = "deploy-property-app-through-ssm"
  role = aws_iam_role.github_ecr_push.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = concat([aws_ssm_document.property_deploy.arn], [for lab in module.lab : lab.instance_arn])
      },
      {
        Effect   = "Allow"
        Action   = "ssm:GetCommandInvocation"
        Resource = "*"
      }
    ]
  })
}
