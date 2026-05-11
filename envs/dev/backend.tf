# ─────────────────────────────────────────────────────────────────────────────
# BACKEND + PROVIDER for the DEV environment
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
    bucket = "cloud-infra-tfstate-dev-952933884165"
    key    = "dev/terraform.tfstate"
    region = "us-east-1"

    # use_lockfile uses S3 native locking — no DynamoDB needed.
    # Creates a .tflock file while apply runs to prevent concurrent changes.
    use_lockfile = true

    # encrypt = true tells S3 to encrypt the state file at rest using AES256.
    # The bucket also has default AES256 encryption set in bootstrap.
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      managed_by = "terraform"
      repo       = "cloud-infra"
    }
  }
}
