resource "aws_security_group" "property_app" {
  name_prefix = "property-app-"
  description = "Security group for property app EC2"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "property-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.property_app.id
  description       = "SSH from my public IP"
  # cidr_ipv4         = var.admin_cidr
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.property_app.id
  description       = "Public HTTPS access"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.property_app.id
  description       = "Public HTTP access"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# resource "aws_vpc_security_group_ingress_rule" "allow_web_ipv4" {
#   security_group_id = aws_security_group.property_app.id
#   description       = "Public Web access"
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 5173
#   to_port           = 5173
#   ip_protocol       = "tcp"
# }

# Deliberately broad for this stage; tighten based on measured app dependencies.
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.property_app.id
  description       = "Allow all outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
