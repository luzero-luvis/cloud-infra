# ─────────────────────────────────────────────────────────────────────────────
# VARIABLES for the PROD environment.
# Same as dev/variables.tf — prod needs the same passphrase to encrypt/decrypt state.
# ─────────────────────────────────────────────────────────────────────────────

variable "state_passphrase" {
  description = "Passphrase used to encrypt and decrypt the Terraform state file"
  type        = string
  sensitive   = true # never printed in logs — shows as (sensitive)
}
