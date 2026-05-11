# ─────────────────────────────────────────────────────────────────────────────
# PROD ENVIRONMENT — main.tf
#
# Same structure as dev/main.tf but with prod-specific values.
# Key differences from dev:
#   - cidr_block is 10.1.0.0/16 (dev uses 10.0.0.0/16 — no IP overlap)
#   - env = "prod" (resources named prod-vpc, prod-subnet etc.)
# ─────────────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../modules/vpc"

  env        = "prod"
  cidr_block = "10.1.0.0/16" # different range from dev (10.0.x.x) so they never clash
  # useful if you ever connect dev and prod via VPC peering

  tags = local.common_tags
}
