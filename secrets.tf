resource "aws_secretsmanager_secret" "property_config" {
  name                    = "property-app/dev/config"
  description             = "Runtime configuration for the property application"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy" "property_config_read" {
  name = "property-app-read-config"
  role = local.property_deploy_ec2_role_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadApplicationConfiguration"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.property_config.arn
      }
    ]
  })
}
