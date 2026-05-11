# ─────────────────────────────────────────────────────────────────────────────
# LOCALS — same as dev/locals.tf but environment tag says "prod".
#
# Having separate locals files per environment means:
#   - dev resources are tagged environment = "dev"
#   - prod resources are tagged environment = "prod"
# This makes it easy to filter resources by environment in the AWS console
# and in billing reports.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  common_tags = {
    environment = "prod"             # identifies this as production infrastructure
    project     = "cloud-infra"
    owner       = "platform-team"
    cost_center = "engineering"
    managed_by  = "terraform"
  }
}
