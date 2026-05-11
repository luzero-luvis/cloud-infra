# ─────────────────────────────────────────────────────────────────────────────
# BACKEND + PROVIDER for the PROD environment
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
    bucket = "cloud-infra-tfstate-prod-952933884165"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"

    # use_lockfile uses S3 native locking — no DynamoDB needed.
    use_lockfile = true

    # encrypt = true enables AES256 server-side encryption on the state file.
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
