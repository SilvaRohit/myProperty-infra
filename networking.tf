module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_dns_support      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = false
  enable_nat_gateway      = false
}

resource "aws_eip" "existing_property_app" {
  provider = aws.existing
  domain   = "vpc"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip_association" "existing_property_app" {
  provider           = aws.existing
  allocation_id      = aws_eip.existing_property_app.id
  instance_id        = aws_instance.property_app.id
  private_ip_address = "10.0.1.148"

  lifecycle {
    prevent_destroy = true
  }
}

