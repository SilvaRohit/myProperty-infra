variable "aws_account_id" {
  description = "Your intended 12-digit AWS account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Enter a 12-digit AWS account ID."
  }
}
variable "aws_region" {
  type    = string
  default = "ap-southeast-7"
}
variable "project_name" {
  type    = string
  default = "property-app"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "vpc_name" {
  type    = string
  default = "custom-vpc1"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-7a", "ap-southeast-7b", "ap-southeast-7c"]
  validation {
    condition     = length(var.availability_zones) == 3 && length(distinct(var.availability_zones)) == 3
    error_message = "Specify three distinct AZs in your chosen region."
  }
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) == 3
    error_message = "Specify three public subnet CIDRs."
  }
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) == 3
    error_message = "Specify three private subnet CIDRs."
  }
}
variable "instance_type" {
  description = "An x86_64 type compatible with the pinned Ubuntu AMI"
  type        = string
  default     = "t3.micro"
}
variable "instance_name" {
  type    = string
  default = "property-app"
}
variable "key_pair_name" {
  description = "Existing EC2 key pair NAME in the selected region"
  type        = string
}
variable "admin_cidr" {
  description = "Your public IPv4 /32; applies to SSH only"
  type        = string
  # validation {
  #   condition     = can(cidrnetmask(var.admin_cidr)) && can(regex("/32$", var.admin_cidr))
  #   error_message = "Enter a valid IPv4 address followed by /32."
  # }
}
variable "ubuntu_ami_id" {
  description = "Pinned Canonical Ubuntu x86_64 AMI ID in the selected region"
  type        = string
  validation {
    condition     = can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ubuntu_ami_id))
    error_message = "Supply a real AMI ID for your region."
  }
}

#Github OIDC variables
variable "existing_github_oidc_provider_arn" {
  description = "Existing account-wide GitHub IAM OIDC provider ARN, or empty to create one."
  type        = string
  default     = ""

  validation {
    condition = (
      var.existing_github_oidc_provider_arn == "" ||
      var.existing_github_oidc_provider_arn == "arn:aws:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
    )
    error_message = "Use the GitHub OIDC provider ARN from this AWS account, or an empty string."
  }
}

variable "github_ecr_oidc_subject" {
  description = "Exact subject claim for SilvaRohit/myProperty on aws-deployment. No wildcard branches."
  type        = string
  # Repository created 2026-10-06, after GitHub's immutable-subject cutoff.
  # Public API IDs: owner 42529933; repository 1407685091.
  default = "repo:SilvaRohit@42529933/myProperty@1407685091:ref:refs/heads/aws-deployment"

  validation {
    condition = contains([
      "repo:SilvaRohit@42529933/myProperty@1407685091:ref:refs/heads/aws-deployment",
      "repo:SilvaRohit/myProperty:ref:refs/heads/aws-deployment",
    ], var.github_ecr_oidc_subject)
    error_message = "Only this repository's immutable or legacy subject on aws-deployment is allowed."
  }
}

#Github Auto-deploy variables
variable "deployment_existing_ec2_role_name" {
  description = "Role currently attached to the property EC2 instance, or empty to create a new EC2 role. Enter the IAM ROLE name, not its ARN or instance-profile name."
  type        = string
  default     = ""

  validation {
    condition     = var.deployment_existing_ec2_role_name == "" || can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.deployment_existing_ec2_role_name))
    error_message = "Enter an IAM role name or leave empty when EC2 has no role."
  }
}

