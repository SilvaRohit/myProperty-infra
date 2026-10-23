resource "aws_sns_topic" "property_alerts" {
  name         = "property-app-dev-alerts"
  display_name = "TeceroTech Property Alerts"
}

resource "aws_sns_topic_subscription" "property_alert_email" {
  topic_arn = aws_sns_topic.property_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

