# ─────────────────────────────────────────────────────────────────────────────
# DEV ENVIRONMENT — main.tf
#
# This file defines WHAT infrastructure to create in the dev environment.
# It calls reusable modules (like functions in programming) instead of
# writing all the resource code here directly.
#
# Think of it like ordering from a menu:
#   - The module is the kitchen (knows how to cook)
#   - main.tf is your order (what you want and how you want it)
# ─────────────────────────────────────────────────────────────────────────────

# Call the VPC module to create networking infrastructure for dev.
# The module lives in modules/vpc/ — it contains the actual resource code.
# We just pass in the settings (inputs) we want for dev.
module "vpc" {
  source = "../../modules/vpc" # path to the module folder

  env        = "dev"       # tells the module this is the dev environment
                           # used for naming resources: "dev-vpc", "dev-subnet" etc.
  cidr_block = "10.0.0.0/16" # the IP address range for the entire dev VPC
                              # /16 gives 65,536 possible IP addresses
                              # dev uses 10.0.x.x, prod uses 10.1.x.x (no overlap)

  tags = local.common_tags # pass the shared tags from locals.tf to all VPC resources
}
