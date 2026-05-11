# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES — inputs you can change without editing the main code.
#
# Think of variables like the settings on a TV remote.
# The TV (Terraform code) is the same — you just change the settings.
# ─────────────────────────────────────────────────────────────────────────────

variable "region" {
  description = "AWS region where all resources will be created"
  type        = string  # must be text (not a number or true/false)
  default     = "us-east-1" # if you do not set this, us-east-1 is used automatically
}

variable "environments" {
  description = "List of environments to create state buckets for"
  type        = list(string)        # a list of text values
  default     = ["dev", "prod"]     # creates two buckets: one for dev, one for prod
  # To add staging: default = ["dev", "staging", "prod"]
}

variable "github_repo" {
  description = "Your GitHub repo in format: owner/repo-name"
  type        = string
  default     = "luzero-luvis/cloud-infra"
  # This is used in the OIDC trust policy.
  # Only GitHub Actions jobs from THIS repo can authenticate with AWS.
  # If you fork or rename the repo, update this value and re-run bootstrap.
}
