locals {
  property_dashboard_charts = [
    {
      title   = "EC2 CPU usage (%)"
      stat    = "Average"
      metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.property_app.id]]
    },
    {
      title   = "EC2 memory usage (%)"
      stat    = "Average"
      metrics = [["CWAgent", "mem_used_percent", "InstanceId", aws_instance.property_app.id]]
    },
    {
      title   = "EC2 root disk usage (%)"
      stat    = "Maximum"
      metrics = [["CWAgent", "disk_used_percent", "InstanceId", aws_instance.property_app.id]]
    },
    {
      title   = "EC2 status checks (0 = healthy)"
      stat    = "Maximum"
      metrics = [["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.property_app.id]]
    },
    {
      title   = "RDS CPU usage (%)"
      stat    = "Average"
      metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.existing_property_db.identifier]]
    },
    {
      title   = "RDS database connections"
      stat    = "Maximum"
      metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.existing_property_db.identifier]]
    },
    {
      title   = "RDS free storage"
      stat    = "Minimum"
      metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.existing_property_db.identifier]]
    },
    {
      title   = "RDS freeable memory"
      stat    = "Minimum"
      metrics = [["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", aws_db_instance.existing_property_db.identifier]]
    }
  ]
}

resource "aws_cloudwatch_dashboard" "property" {
  dashboard_name = "property-app-dev"

  dashboard_body = jsonencode({
    start          = "-PT3H"
    periodOverride = "inherit"

    widgets = concat(
      [
        {
          type   = "alarm"
          x      = 0
          y      = 0
          width  = 24
          height = 3

          properties = {
            title  = "Property application alarms"
            sortBy = "stateUpdatedTimestamp"

            alarms = concat(
              [for alarm in aws_cloudwatch_metric_alarm.property_ec2_usage : alarm.arn],
              [for alarm in aws_cloudwatch_metric_alarm.property_rds : alarm.arn]
            )
          }
        }
      ],
      [
        for index, chart in local.property_dashboard_charts : {
          type   = "metric"
          x      = (index % 2) * 12
          y      = 3 + floor(index / 2) * 6
          width  = 12
          height = 6

          properties = {
            title   = chart.title
            region  = var.aws_region
            view    = "timeSeries"
            period  = 300
            stat    = chart.stat
            metrics = chart.metrics
          }
        }
      ]
    )
  })
}