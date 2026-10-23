locals {
  property_ec2_usage_alarms = {
    disk = {
      metric_name = "disk_used_percent"
      threshold   = 80
      statistic   = "Maximum"
      description = "EC2 root disk usage is high"
    }

    memory = {
      metric_name = "mem_used_percent"
      threshold   = 85
      statistic   = "Average"
      description = "EC2 memory usage is high"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "property_ec2_usage" {
  for_each = local.property_ec2_usage_alarms

  alarm_name        = "property-app-dev-ec2-${each.key}-high"
  alarm_description = each.value.description

  namespace   = "CWAgent"
  metric_name = each.value.metric_name
  statistic   = each.value.statistic

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = each.value.threshold

  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3

  dimensions = {
    InstanceId = aws_instance.property_app.id
  }

  treat_missing_data = "missing"
  actions_enabled    = true

  alarm_actions             = [aws_sns_topic.property_alerts.arn]
  ok_actions                = [aws_sns_topic.property_alerts.arn]
  insufficient_data_actions = [aws_sns_topic.property_alerts.arn]

  depends_on = [aws_sns_topic_policy.property_alerts]
}