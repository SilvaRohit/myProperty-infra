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

output "instance_arn" {
  value = aws_instance.property_app.arn
}

output "private_dns" {
  value = aws_instance.property_app.private_dns
}

output "public_ip" {
  value = aws_instance.property_app.public_ip
}

output "database_address" {
  value = aws_db_instance.existing_property_db.address
}

output "database_endpoint" {
  value = aws_db_instance.existing_property_db.endpoint
}

output "database_identifier" {
  value = aws_db_instance.existing_property_db.identifier
}
