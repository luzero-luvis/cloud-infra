# ─────────────────────────────────────────────────────────────────────────────
# OUTPUTS — values printed to the terminal after terraform apply finishes.
#
# Think of outputs like a receipt after shopping.
# Terraform did its work — outputs tell you what it created.
# You can also use outputs to pass values between terraform modules.
# ─────────────────────────────────────────────────────────────────────────────

output "state_bucket_names" {
  description = "S3 bucket names created for Terraform state"
  # loops over all buckets and returns: { dev = "cloud-infra-tfstate-dev-952933884165", prod = "..." }
  value = { for k, v in aws_s3_bucket.tfstate : k => v.bucket }
}

output "github_actions_role_arns" {
  description = "Copy these ARNs into GitHub Secrets: AWS_ROLE_DEV and AWS_ROLE_PROD"
  # ARN = Amazon Resource Name — a unique address for any AWS resource
  # Example: arn:aws:iam::952933884165:role/github-actions-dev
  value = {
    dev  = aws_iam_role.github_actions_dev.arn
    prod = aws_iam_role.github_actions_prod.arn
  }
}
