variable "lab_enabled" {
  description = "Keep true for normal operation; false deletes only the disposable lab module after backup/protection preparation."
  type        = bool
  default     = true
}

variable "rebuild_mode" {
  description = "existing preserves the imported lab; fresh creates propertyapp and initializes an empty schema; restore uses a named DB snapshot."
  type        = string
  default     = "existing"
  validation {
    condition     = contains(["existing", "fresh", "restore"], var.rebuild_mode) && (var.rebuild_mode == "existing" || !var.adopt_legacy_database_security_group)
    error_message = "Choose existing, fresh or restore. Disable legacy SG adoption before a fresh/restore rebuild."
  }
}

variable "adopt_legacy_database_security_group" {
  description = "One-time import of the existing RDS SG and its app-source PostgreSQL rule. Set false after adoption."
  type        = bool
  default     = true
}

variable "database_deletion_protection" {
  description = "AWS deletion protection. Disable in a separate reviewed apply before setting lab_enabled=false."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Choose a new unused final snapshot name before each deliberate lab teardown."
  type        = string
  default     = "property-app-db-final"
}

variable "database_snapshot_identifier" {
  description = "Exact retained snapshot identifier for restore mode."
  type        = string
  default     = ""
}

variable "database_password_version" {
  description = "Increment after changing DATABASE_PASSWORD in the retained application secret."
  type        = number
  default     = 1
}

variable "initial_image_uri" {
  description = "Exact successful immutable ECR image used to start a new host before the next GitHub deployment."
  type        = string
  default     = ""
  validation {
    condition     = var.initial_image_uri == "" || can(regex("^147997138960\\.dkr\\.ecr\\.ap-southeast-7\\.amazonaws\\.com/property-app-dev:sha-[0-9a-f]{40}-run-[0-9]+-[0-9]+$", var.initial_image_uri))
    error_message = "Use a complete immutable versioned image URI from property-app-dev."
  }
}

variable "uploads_restore_s3_prefix" {
  description = "Optional S3 uploads archive prefix to restore on a new primary host."
  type        = string
  default     = ""
}

variable "rehearsal_enabled" {
  description = "Create a parallel independent VPC, EC2 and fresh/restored RDS for recovery testing."
  type        = bool
  default     = false
}

variable "rehearsal_snapshot_identifier" {
  description = "Empty tests a clean database; nonempty restores this snapshot into the rehearsal."
  type        = string
  default     = ""
}

variable "rehearsal_uploads_s3_prefix" {
  description = "Optional uploads backup prefix for the isolated rehearsal."
  type        = string
  default     = ""
}
