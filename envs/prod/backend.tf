# ─────────────────────────────────────────────────────────────────────────────
# BACKEND + PROVIDER + ENCRYPTION for the PROD environment
#
# Same structure as dev/backend.tf but pointing to the prod S3 bucket.
# Prod and dev NEVER share a state file — they are completely independent.
# Why? If dev state gets corrupted, prod is not affected. Total isolation.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "cloud-infra-tfstate-prod-952933884165" # separate bucket for prod
    key    = "prod/terraform.tfstate"                # separate key (file path) for prod
    region = "us-east-1"

    # Same locking mechanism as dev — prevents concurrent applies on prod.
    # Even more important in prod where mistakes cost real money.
    use_lockfile = true
    encrypt      = true
  }

}

provider "aws" {
  region = "us-east-1"

  # default_tags — same as dev but environment tag will say "prod" in locals.tf
  default_tags {
    tags = {
      managed_by = "terraform"
      repo       = "cloud-infra"
    }
  }
}
