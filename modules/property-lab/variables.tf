variable "aws_account_id" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "prefix" {
  type = string
}

variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "key_pair_name" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "rebuild_mode" {
  type = string
}

variable "database_identifier" {
  type = string
}

variable "database_engine_version" {
  type = string
}

variable "database_snapshot_identifier" {
  type = string
}

variable "database_password_version" {
  type = number
}

variable "database_deletion_protection" {
  type = bool
}

variable "final_snapshot_identifier" {
  type = string
}

variable "elastic_ip_allocation_id" {
  type = string
}

variable "application_secret_arn" {
  type = string
}

variable "initial_image_uri" {
  type = string
}

variable "uploads_restore_s3_prefix" {
  type = string
}

variable "enable_https" {
  type = bool
}

variable "enable_backups" {
  type = bool
}

variable "take_final_snapshot" {
  type = bool
}
