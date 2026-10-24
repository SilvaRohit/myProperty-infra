output "vpc_id" {
  value = try(module.lab[0].vpc_id, null)
}
output "public_subnet_ids" {
  value = try(module.lab[0].public_subnet_ids, null)
}
output "private_subnet_ids" {
  value = try(module.lab[0].private_subnet_ids, null)
}
output "security_group_id" {
  value = try(module.lab[0].security_group_id, null)
}
output "instance_id" {
  value = try(module.lab[0].instance_id, null)
}
output "instance_hostname" {
  description = "Private DNS name; not your public website address"
  value       = try(module.lab[0].private_dns, null)
}
output "public_ip" {
  value = try(module.lab[0].public_ip, null)
}
output "selected_ami_id" {
  value = data.aws_ami.ubuntu.id
}

#RDS Outputs
output "rds_endpoint" {
  description = "Existing RDS host and port; not a password."
  value       = try(module.lab[0].database_endpoint, null)
}

output "rds_address" {
  description = "Existing RDS hostname for the application's DATABASE_HOST."
  value       = try(module.lab[0].database_address, null)
}

output "elastic_ip_address" {
  value = aws_eip.existing_property_app.public_ip
}

output "property_website" {
  value = "https://property.tecerotech.com"
}

#ECR Outputs
output "ecr_repository_name" {
  value = aws_ecr_repository.property_app.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.property_app.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.property_app.arn
}

#GitHub OIDC Outputs
output "github_ecr_push_role_arn" {
  value = aws_iam_role.github_ecr_push.arn
}

#Github Autodeploy Outputs
output "deployment_ec2_instance_id" {
  value = try(module.lab[0].instance_id, null)
}

output "deployment_ssm_document_name" {
  value = aws_ssm_document.property_deploy.name
}

output "deployment_ec2_role_name" {
  value = local.property_deploy_ec2_role_name
}

#Github Rollback Outputs
output "rollback_ssm_document_name" {
  value = aws_ssm_document.property_rollback.name
}

#S3 Backups Outputs
output "uploads_backup_bucket" {
  description = "S3 bucket for uploaded-document backups."
  value       = aws_s3_bucket.property_backups.id
}

#Secrets Outputs
output "application_secret_arn" {
  description = "ARN of the application configuration secret."
  value       = aws_secretsmanager_secret.property_config.arn
}

#SNS Alerts Outputs
output "alerts_topic_arn" {
  description = "SNS topic used for monitoring notifications"
  value       = aws_sns_topic.property_alerts.arn
}

#CloudWatch LogsGroup Outputs
output "application_log_group_name" {
  description = "CloudWatch log group for application logs"
  value       = aws_cloudwatch_log_group.property_app.name
}

output "deployment_target_parameter" {
  value = aws_ssm_parameter.deployment_target.name
}
output "rehearsal" {
  value = var.rehearsal_enabled ? { instance_id = module.rehearsal[0].instance_id, public_ip = module.rehearsal[0].public_ip, database_address = module.rehearsal[0].database_address } : null
}
