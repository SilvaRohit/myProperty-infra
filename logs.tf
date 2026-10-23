resource "aws_cloudwatch_log_group" "property_app" {
  name              = "/tecerotech/property-app/dev"
  retention_in_days = 7

  tags = {
    Name = "property-app-dev-logs"
  }
}

resource "aws_iam_role_policy" "property_application_logs" {
  name = "property-app-cloudwatch-logs"
  role = var.deployment_existing_ec2_role_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "WriteApplicationLogs"
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "${aws_cloudwatch_log_group.property_app.arn}:log-stream:*"
      }
    ]
  })
}
