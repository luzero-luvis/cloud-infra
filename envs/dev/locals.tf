# ─────────────────────────────────────────────────────────────────────────────
# LOCALS — values computed once and reused across this environment.
#
# locals are like constants in programming — you define a value once
# and reference it many times. If you need to change it, change it in one place.
#
# Why use locals for tags?
# Every resource in AWS should have the same base tags.
# Instead of copy-pasting the same tags into every resource,
# we define them here and pass local.common_tags wherever needed.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  common_tags = {
    environment = "dev"              # which environment this resource belongs to
    project     = "cloud-infra"      # which project owns this resource
    owner       = "platform-team"    # which team is responsible for this resource
    cost_center = "engineering"      # used for AWS cost reports — who pays for this?
    managed_by  = "terraform"        # signals: do NOT manually edit this in the console
  }
}
