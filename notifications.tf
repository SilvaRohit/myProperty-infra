resource "aws_sns_topic" "property_alerts" {
  name         = "property-app-dev-alerts"
  display_name = "TeceroTech Property Alerts"
}

resource "aws_sns_topic_subscription" "property_alert_email" {
  topic_arn = aws_sns_topic.property_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_policy" "property_alerts" {
  arn = aws_sns_topic.property_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPropertyCloudWatchAlarms"
        Effect = "Allow"

        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }

        Action   = "sns:Publish"
        Resource = aws_sns_topic.property_alerts.arn

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "147997138960"
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:cloudwatch:ap-southeast-7:147997138960:alarm:property-app-dev-*"
          }
        }
      }
    ]
  })
}