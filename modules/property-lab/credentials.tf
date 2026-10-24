# password_wo is write-only. The ephemeral secret read never enters state/plan files.
# In existing mode no secret value is read by Terraform and no password is changed.
ephemeral "aws_secretsmanager_secret_version" "application" {
  count     = var.rebuild_mode == "existing" ? 0 : 1
  secret_id = var.application_secret_arn
}

locals {
  database_password_line = var.rebuild_mode == "existing" ? null : trimspace(one(regexall(
    "(?m)^[ \t]*(?:export[ \t]+)?DATABASE_PASSWORD[ \t]*=[ \t]*(.*)$",
    ephemeral.aws_secretsmanager_secret_version.application[0].secret_string
  ))[0])
  # Require a single one-line password entry, without an inline comment.
  # Support unquoted, single-quoted and JSON-compatible double-quoted strings.
  database_password = var.rebuild_mode == "existing" ? null : (
    startswith(local.database_password_line, "\"") ? jsondecode(local.database_password_line) : (
      startswith(local.database_password_line, "'") && endswith(local.database_password_line, "'") ?
      substr(local.database_password_line, 1, length(local.database_password_line) - 2) : local.database_password_line
    )
  )
}
