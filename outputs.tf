output "vpc_id" {
  value = module.vpc.vpc_id
}
output "public_subnet_ids" {
  value = module.vpc.public_subnets
}
output "private_subnet_ids" {
  value = module.vpc.private_subnets
}
output "security_group_id" {
  value = aws_security_group.property_app.id
}
output "instance_id" {
  value = aws_instance.property_app.id
}
output "instance_hostname" {
  description = "Private DNS name; not your public website address"
  value       = aws_instance.property_app.private_dns
}
output "public_ip" {
  value = aws_instance.property_app.public_ip
}
output "selected_ami_id" {
  value = aws_instance.property_app.ami
}

#RDS Outputs
output "rds_endpoint" {
  description = "Existing RDS host and port; not a password."
  value       = aws_db_instance.existing_property_db.endpoint
}

output "rds_address" {
  description = "Existing RDS hostname for the application's DATABASE_HOST."
  value       = aws_db_instance.existing_property_db.address
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
  value = aws_instance.property_app.id
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
