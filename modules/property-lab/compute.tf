resource "aws_instance" "property_app" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_pair_name
  iam_instance_profile = var.instance_profile_name

  user_data_base64            = var.rebuild_mode == "existing" ? null : local.user_data
  user_data_replace_on_change = var.rebuild_mode != "existing"

  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.property_app.id]


  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 30
  }
  lifecycle {
    precondition {
      condition     = var.rebuild_mode == "existing" ? true : length(local.user_data) <= 21844
      error_message = "Compressed bootstrap exceeds the EC2 16 KiB user-data limit."
    }
  }

  depends_on = [module.vpc]

  tags = {
    Name      = var.instance_name
    Portfolio = "TeceroTech-HCP"
  }
}
