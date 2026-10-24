# Terraform 1.16 cannot validate ephemeral resources through mock_provider,
# even when their count is zero. Use the real provider's local validation with
# dummy credentials instead. Both runs are plan-only, remote AMI reads are
# overridden, imports are disabled, and existing mode never opens the secret.
provider "aws" {
  region                      = "ap-southeast-7"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

provider "aws" {
  alias                       = "existing"
  region                      = "ap-southeast-7"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
}

override_data {
  target = data.aws_ami.ubuntu
  values = { id = "ami-0123456789abcdef0" }
}
variables {
  aws_account_id                    = "147997138960"
  ubuntu_ami_id                     = "ami-0123456789abcdef0"
  key_pair_name                     = "test-key"
  admin_cidr                        = "0.0.0.0/0"
  alert_email                       = "example@example.com"
  deployment_existing_ec2_role_name = "instanceRole"
  # These offline plans must not import a real AWS security group.
  adopt_legacy_database_security_group = false
}
run "existing_lab_preserved" {
  command = plan
  assert {
    condition     = length(module.lab) == 1 && length(module.rehearsal) == 0
    error_message = "Defaults must preserve one primary lab and no rehearsal."
  }
  assert {
    condition     = var.rebuild_mode == "existing" && var.database_deletion_protection
    error_message = "Adoption must not opt into a rebuild or disable database protection."
  }
}
run "offline_retains_foundation" {
  command = plan
  variables {
    lab_enabled = false
  }
  assert {
    condition     = length(module.lab) == 0 && aws_ssm_parameter.deployment_target.value == "offline"
    error_message = "An offline lab must have no disposable module and must not expose a stale deployment ID."
  }
  assert {
    condition     = aws_s3_bucket.property_backups.force_destroy == false && aws_ecr_repository.property_app.force_delete == false
    error_message = "Turning off the lab must retain backups and images."
  }
}
