resource "aws_iam_role_policy" "property_cloudwatch_metrics" {
  name = "property-app-cloudwatch-agent-metrics"
  role = var.deployment_existing_ec2_role_name

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "PublishAgentMetrics"
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"

        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CWAgent"
          }
        }
      },
      {
        Sid    = "ReadEC2MetricMetadata"
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      }
    ]
  })
}