# Keep these moves for existing HCP state. They do not recreate AWS resources.
moved {
  from = module.vpc
  to   = module.lab[0].module.vpc
}

moved {
  from = aws_instance.property_app
  to   = module.lab[0].aws_instance.property_app
}

moved {
  from = aws_security_group.property_app
  to   = module.lab[0].aws_security_group.property_app
}

moved {
  from = aws_db_instance.existing_property_db
  to   = module.lab[0].aws_db_instance.existing_property_db
}

moved {
  from = aws_db_subnet_group.existing_property_db
  to   = module.lab[0].aws_db_subnet_group.existing_property_db
}

moved {
  from = aws_eip_association.existing_property_app
  to   = module.lab[0].aws_eip_association.existing_property_app[0]
}

moved {
  from = aws_cloudwatch_dashboard.property
  to   = aws_cloudwatch_dashboard.property[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.allow_ssh_ipv4
  to   = module.lab[0].aws_vpc_security_group_ingress_rule.allow_ssh_ipv4
}

moved {
  from = aws_vpc_security_group_ingress_rule.allow_tls_ipv4
  to   = module.lab[0].aws_vpc_security_group_ingress_rule.allow_tls_ipv4
}

moved {
  from = aws_vpc_security_group_ingress_rule.allow_http_ipv4
  to   = module.lab[0].aws_vpc_security_group_ingress_rule.allow_http_ipv4
}

moved {
  from = aws_vpc_security_group_egress_rule.allow_all_traffic_ipv4
  to   = module.lab[0].aws_vpc_security_group_egress_rule.allow_all_traffic_ipv4
}
