# ─────────────────────────────────────────────────────────────────────────────
# BACKEND + PROVIDER + ENCRYPTION for the DEV environment
#
# This file answers three questions:
#   1. Where does Terraform save its state file? (backend)
#   2. Which cloud does Terraform talk to? (provider)
#   3. How is the state file encrypted? (encryption)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  # Minimum Terraform version required to use this code.
  # We need 1.10+ because:
  #   - use_lockfile (native S3 locking) was added in 1.10
  #   - the encryption block was added in 1.10
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws" # official AWS plugin by HashiCorp
      version = "~> 5.0"        # any version 5.x — compatible updates only
    }
  }

  # ── BACKEND ────────────────────────────────────────────────────────────────
  # The backend tells Terraform WHERE to store the state file.
  # Instead of keeping it on your laptop (dangerous, not shareable),
  # we store it in an S3 bucket so everyone on the team uses the same state.

  backend "s3" {
    bucket = "cloud-infra-tfstate-dev-952933884165" # the S3 bucket bootstrap created
    key    = "dev/terraform.tfstate"                # path inside the bucket for this file
    region = "us-east-1"                            # the region the bucket lives in

    # use_lockfile = true means: use S3's native locking instead of DynamoDB.
    # When someone runs terraform apply, S3 creates a .tflock file.
    # If another person runs apply at the same time, they see the lock and wait.
    # This prevents two people from changing infrastructure at the same time
    # and corrupting the state file.
    use_lockfile = true

    # encrypt = true tells Terraform to ask S3 to encrypt the file at rest.
    # This works together with the bucket's AES256 encryption we set in bootstrap.
    encrypt = true
  }

  # ── ENCRYPTION BLOCK ───────────────────────────────────────────────────────
  # This adds a SECOND layer of encryption on top of S3's encryption.
  #
  # S3 encryption (above):  AWS encrypts the file using their key — they can read it
  # Passphrase encryption:  YOU encrypt it using your passphrase — only you can read it
  #
  # Even if an AWS employee or hacker got into your S3 bucket,
  # the file is scrambled with your passphrase and unreadable.
  #
  # How to set the passphrase:
  #   export TF_VAR_state_passphrase="your-secret-phrase"
  # The TF_VAR_ prefix tells Terraform to use it as a variable value.

  encryption {
    # pbkdf2 = "Password-Based Key Derivation Function 2"
    # This converts your human-readable passphrase into a cryptographic key.
    # It runs the passphrase through a complex math function thousands of times
    # so that guessing it by brute force is extremely slow.
    key_provider "pbkdf2" "local" {
      passphrase = var.state_passphrase # comes from variables.tf, set via env var
    }

    # aes_gcm = "Advanced Encryption Standard - Galois/Counter Mode"
    # This is the actual encryption algorithm used to scramble the file.
    # AES-GCM is the same standard used by banks and governments.
    method "aes_gcm" "default" {
      keys = key_provider.pbkdf2.local # use the key derived from our passphrase
    }

    # Encrypt the state file (terraform.tfstate) using the method above
    state {
      method = method.aes_gcm.default
    }

    # Also encrypt the plan file (terraform plan -out=tfplan)
    # Plan files can also contain sensitive data, so encrypt them too
    plan {
      method = method.aes_gcm.default
    }
  }
}

# ── PROVIDER ─────────────────────────────────────────────────────────────────
# The provider tells Terraform which cloud to talk to and how.
# Without this, Terraform does not know whether to create AWS, Azure, or GCP resources.

provider "aws" {
  region = "us-east-1" # all resources in this environment go to us-east-1

  # default_tags automatically adds these tags to EVERY resource Terraform creates.
  # Why? So you can always tell in the AWS console which resources Terraform manages
  # and which repo they came from. Saves hours of confusion in large accounts.
  default_tags {
    tags = {
      managed_by = "terraform"   # "a human did not click this in the console"
      repo       = "cloud-infra" # "this came from the cloud-infra repo"
    }
  }
}
