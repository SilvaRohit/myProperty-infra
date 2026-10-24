mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}
mock_provider "aws" {
  alias = "existing"
}
variables {
  aws_account_id                    = "147997138960"
  ubuntu_ami_id                     = "ami-0123456789abcdef0"
  key_pair_name                     = "test-key"
  admin_cidr                        = "0.0.0.0/0"
  alert_email                       = "example@example.com"
  deployment_existing_ec2_role_name = "instanceRole"
  # Mock plans have no real AWS SG to import.
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
