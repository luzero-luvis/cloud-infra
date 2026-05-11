# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES — inputs that must be provided before Terraform can run.
#
# Unlike locals (which are computed inside Terraform),
# variables come from OUTSIDE — the user, environment variables, or CI/CD.
# ─────────────────────────────────────────────────────────────────────────────

variable "state_passphrase" {
  description = "Passphrase used to encrypt and decrypt the Terraform state file"
  type        = string # must be text

  # sensitive = true means:
  #   - Terraform will NOT print this value in logs or plan output
  #   - It will show as (sensitive) instead of the actual value
  #   - Prevents the passphrase from leaking into GitHub Actions logs
  sensitive = true

  # No default value — Terraform will error if this is not set.
  # Set it with: export TF_VAR_state_passphrase="your-passphrase"
  # In GitHub Actions it comes from the STATE_PASSPHRASE secret.
}
