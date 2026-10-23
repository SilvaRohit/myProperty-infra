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

#RDS Alarms
locals {
  property_rds_alarms = {
    cpu = {
      metric_name         = "CPUUtilization"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      threshold           = 80
      statistic           = "Average"
      description         = "Property database CPU usage is high"
    }

    storage = {
      metric_name         = "FreeStorageSpace"
      comparison_operator = "LessThanThreshold"
      threshold           = 5 * 1024 * 1024 * 1024
      statistic           = "Minimum"
      description         = "Property database has less than 5 GiB free storage"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "property_rds" {
  for_each = local.property_rds_alarms

  alarm_name        = "property-app-dev-rds-${each.key}"
  alarm_description = each.value.description

  namespace           = "AWS/RDS"
  metric_name         = each.value.metric_name
  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  statistic           = each.value.statistic

  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.existing_property_db.identifier
  }

  treat_missing_data = "missing"
  actions_enabled    = true

  alarm_actions             = [aws_sns_topic.property_alerts.arn]
  ok_actions                = [aws_sns_topic.property_alerts.arn]
  insufficient_data_actions = [aws_sns_topic.property_alerts.arn]

  depends_on = [aws_sns_topic_policy.property_alerts]
}