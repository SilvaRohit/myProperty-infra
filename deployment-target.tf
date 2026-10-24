resource "aws_ssm_parameter" "deployment_target" {
  name        = "/property-app/dev/deployment/instance-id"
  description = "Current property application EC2 target, or offline when the lab is disabled"
  type        = "String"
  value       = var.lab_enabled ? module.lab[0].instance_id : "offline"
}

resource "aws_iam_role_policy" "github_property_target" {
  name = "read-property-deployment-target"
  role = aws_iam_role.github_ecr_push.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = aws_ssm_parameter.deployment_target.arn
    }]
  })
}
