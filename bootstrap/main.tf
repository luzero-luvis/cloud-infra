# ─────────────────────────────────────────────────────────────────────────────
# BOOTSTRAP — run this ONCE before anything else.
#
# Problem: Terraform needs an S3 bucket to store its state file.
#          But that bucket does not exist yet.
#          So we create the bucket here using LOCAL state (stored on your laptop).
#
# After this runs once:
#   - S3 buckets exist for dev and prod
#   - GitHub Actions can store state there
#   - You never run bootstrap again (unless you add environments)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  # We need Terraform version 1.10 or newer.
  # Why 1.10? Because use_lockfile (native S3 locking) was added in 1.10.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws" # download the AWS plugin from HashiCorp's registry
      version = "~> 5.0"        # use any 5.x version (e.g. 5.1, 5.99) but NOT 6.x
    }
  }

  # NO backend block here on purpose.
  # Every other terraform folder saves state to S3.
  # But bootstrap cannot do that — the S3 bucket does not exist yet!
  # So bootstrap saves its state to a local file: bootstrap/terraform.tfstate
  # Keep this file safe — it tracks what bootstrap created.
}

# This data source reads your current AWS account details.
# We use it below to get your account ID number (e.g. 952933884165).
# Why? S3 bucket names must be globally unique across the ENTIRE world.
# Adding your account ID to the name makes it unique to you.
data "aws_caller_identity" "current" {}

# Tell Terraform which AWS region to create everything in.
# var.region comes from variables.tf (default: us-east-1)
provider "aws" {
  region = var.region
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 BUCKETS — one per environment (dev, prod)
#
# These buckets store the Terraform state files.
# The state file is Terraform's memory — it remembers what it already created.
# Without the state file, Terraform would try to create everything again.
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  # for_each loops over the list ["dev", "prod"] and creates one bucket each.
  # each.key will be "dev" on the first loop, "prod" on the second.
  for_each = toset(var.environments)

  # Bucket name format: cloud-infra-tfstate-dev-952933884165
  # We add the account ID so the name is globally unique.
  # No two people in the world will have the same account ID.
  bucket = "cloud-infra-tfstate-${each.key}-${data.aws_caller_identity.current.account_id}"

  # force_destroy = false means: refuse to delete this bucket if it has files in it.
  # Why? To prevent accidental deletion of your entire state history.
  # If you ever need to delete it, you must empty it manually first.
  force_destroy = false

  tags = {
    environment = each.key    # "dev" or "prod"
    managed_by  = "terraform"
    purpose     = "terraform-state"
  }
}

# ── VERSIONING ────────────────────────────────────────────────────────────────
# Versioning keeps old copies of the state file every time it changes.
# Why? If someone runs a bad terraform apply that breaks everything,
# you can go to S3, find the previous version of the state file,
# and restore it. It's like an "undo" button for your infrastructure.

resource "aws_s3_bucket_versioning" "tfstate" {
  for_each = aws_s3_bucket.tfstate # loop over the same buckets we created above

  bucket = each.value.id # attach versioning to this specific bucket

  versioning_configuration {
    status = "Enabled" # turn versioning ON
  }
}

# ── ENCRYPTION ────────────────────────────────────────────────────────────────
# Encrypt every file stored in the bucket using AES256.
# Why? The state file contains sensitive data — resource IDs, IP addresses,
# sometimes even secrets. Encryption means even if someone gets into S3,
# they cannot read the files.
# AES256 = AWS manages the encryption key (simple, free, secure enough).

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  for_each = aws_s3_bucket.tfstate

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # encrypt using AES-256 standard
    }
  }
}

# ── PUBLIC ACCESS BLOCK ───────────────────────────────────────────────────────
# These four settings together completely block all public access to the bucket.
# Why? State files must NEVER be public — they contain sensitive infrastructure info.
# Even if someone tries to make a file public inside the bucket, these settings
# will override and block it.

resource "aws_s3_bucket_public_access_block" "tfstate" {
  for_each = aws_s3_bucket.tfstate

  bucket = each.value.id

  block_public_acls       = true # block any attempt to make files public via ACL
  block_public_policy     = true # block any bucket policy that grants public access
  ignore_public_acls      = true # ignore public ACLs even if someone adds them
  restrict_public_buckets = true # make the bucket fully private, no exceptions
}
