# One-time adoption. Set adopt_legacy_database_security_group=false after applying.
# The rule import assumes the existing SG permits TCP 5432 from the app SG.
# If it does not match, import fails; inspect the rule inventory before changing it.
import {
  for_each = var.lab_enabled && var.adopt_legacy_database_security_group ? { legacy = "sg-0117f4f2a6cad457c" } : {}
  to       = module.lab[0].aws_security_group.database
  id       = each.value
}
import {
  for_each = var.lab_enabled && var.adopt_legacy_database_security_group ? { legacy = "sg-0117f4f2a6cad457c" } : {}
  to       = module.lab[0].aws_security_group_rule.database_from_app
  id       = "${each.value}_ingress_tcp_5432_5432_sg-0392fcf35269983b6"
}
