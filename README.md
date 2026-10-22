# Property app Terraform — improved baseline

This stage preserves the existing public EC2 design and Terraform resource addresses while separating the files. It adds a second public subnet, account safeguards, standard tags and a required pinned AMI.
It is a lab baseline, not a production-ready application. No ALB, RDS, app deployment, TLS certificate, SSM, NAT or monitoring is provisioned.

## Files
- versions.tf: Terraform >=1.10 and AWS provider 5.x constraints (conservative pairing with VPC module 5.19.0).
- providers.tf: region, account guard and default tags.
- variables.tf: inputs.
- networking.tf: existing VPC module, four subnets across two AZs.
- security.tf: SSH from your /32, HTTPS from all IPv4, all IPv4 outbound.
- compute.tf: pinned Canonical AMI lookup and public EC2.
- outputs.tf: resource IDs and addresses.
- terraform.tfvars.example: copy to terraform.tfvars and replace placeholders.
- backend.tf.example: optional remote state configuration; inactive until renamed.
- .gitignore: excludes state, plans, credentials and local values.

## Existing Terraform project: migrate without losing state
1. Back up your project INCLUDING terraform.tfstate and terraform.tfstate.backup securely. Never put these in Git.
2. Work in your EXISTING vpc-ec2-rds directory with its existing state/backend, workspace and profile. Do not run this as an unrelated fresh project against existing infrastructure.
3. Before replacing the old files, run:
   terraform state show aws_instance.property_app
   Record its current ami value and use it as ubuntu_ami_id. This avoids choosing a newer AMI accidentally.
4. Replace the configuration blocks you pasted with these files. Remove those same blocks from old main.tf; Terraform loads ALL .tf files, so duplicates cause errors. Preserve unrelated resources, existing backend configuration and existing variable values.
5. Keep .terraform.lock.hcl. Inspect the existing AWS provider version before changing constraints: this package selects 5.x. If you already use 6.x, do not downgrade a deployed state blindly; retain the existing compatible constraint and review module compatibility.
6. Merge terraform.tfvars.example values into your existing terraform.tfvars. Preserve names, existing CIDRs, AZ order, key pair, instance type and current AMI.
7. Run init, validate and plan below. A second public subnet and its association are expected. Tags may change. Inspect ALL changes: stop and investigate any unexpected VPC/subnet/EC2 destruction or replacement before applying.
Resource addresses remain module.vpc, aws_instance.property_app, aws_security_group.property_app and the three rule addresses from your pasted configuration. Moving a block between files in the same directory does not change its address.

## New project
Extract this folder, copy terraform.tfvars.example to terraform.tfvars and fill in all placeholders.
Use EC2 > AMIs in Thailand to select a verified Canonical Ubuntu 24.04 x86_64 image and record its AMI ID. The data lookup enforces the owner and architecture; the supplied image ID determines the OS release.
The existing key pair must be in the selected region and you must have its matching private key.
Enable the Thailand region in your account if needed.
All CIDRs must be valid, non-overlapping and inside the VPC CIDR. Keep both AZ names in the chosen region.

## Deploy
export AWS_PROFILE=YOUR_LAB_PROFILE
aws sts get-caller-identity
# Confirm account matches your intended lab, then set aws_account_id accordingly.
terraform init
terraform fmt
terraform validate
terraform plan -out=tfplan
# Read the plan before applying.
terraform apply tfplan

For initial creation, local state is used unless you configure the optional backend.
Commit .terraform.lock.hcl after init. Do not commit credentials, private keys, state or plans.

## Network layout
AZ a: public 10.0.1.0/24, private 10.0.2.0/24
AZ b: public 10.0.4.0/24, private 10.0.3.0/24
EC2 remains in public subnet a. Only EC2 explicitly gets a public IPv4.
Private subnets have no NAT-based internet egress. The default NACL is handled by the VPC module.
One EC2 remains a single point of failure.

## Access
Get your current public IPv4:
curl -4 https://checkip.amazonaws.com
Put that IP followed by /32 in admin_cidr. It controls SSH only.
HTTPS stays public independently.
Connect using your matching private key:
ssh -i ~/Downloads/YOUR_KEY.pem ubuntu@PUBLIC_IP
A public IP may change after stop/start. Opening 443 does NOT install a web server or configure TLS.
Deploy a production build and TLS before expecting HTTPS to respond.

## Optional remote state
Provision a separate private S3 state bucket first, with versioning, encryption and public access blocked.
Restrict IAM access to the state and lock objects. Native locking needs GetObject/PutObject/DeleteObject on the lock; state needs appropriate read/write and list access.
Edit backend.tf.example and rename it backend.tf only once ready.
For existing local state, securely back it up, then run terraform init -migrate-state and review the migration prompt.
If you already have a remote backend, retain it instead of creating a duplicate.
Do not put credentials in backend files. Keep the bucket outside this app's destroy lifecycle.
Reference: https://developer.hashicorp.com/terraform/language/backend/s3

## Cost and cleanup
EC2, EBS and public IPv4 can incur charges. No free-tier eligibility assumed.
To remove ONLY infrastructure tracked by this state:
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
Back up required instance data first; the root disk normally deletes with the instance.

## Next stage
Add ALB and ACM TLS, establish SSM access and required egress, then move app compute private.
Add database, backups, secrets, logs and alarms before considering real tenant data.
Validate app operation and recovery; infrastructure creation alone is not a production readiness test.

## Verification
The generated HCL was parsed locally. No AWS deployment or terraform validate was performed here; run those checks in your project.

