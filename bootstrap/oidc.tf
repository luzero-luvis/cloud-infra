# ─────────────────────────────────────────────────────────────────────────────
# OIDC (OpenID Connect) — lets GitHub Actions talk to AWS without passwords.
#
# The old way:  create an AWS user → generate access key + secret key
#               store them in GitHub → they exist forever → security risk
#
# The new way (OIDC):
#   GitHub proves its identity using a signed token (like a passport)
#   AWS checks the token → gives temporary credentials (expires in 1 hour)
#   No permanent keys. Nothing to steal. Nothing to rotate.
#
# You set this up ONCE in bootstrap. After that, GitHub Actions just works.
# ─────────────────────────────────────────────────────────────────────────────

# ── STEP 1: Register GitHub as a trusted identity provider in AWS ─────────────
#
# This is like adding GitHub to your AWS address book.
# AWS now knows: "If a token comes from token.actions.githubusercontent.com,
# I can verify it is genuine."

resource "aws_iam_openid_connect_provider" "github" {
  # GitHub's OIDC URL — this is where GitHub issues identity tokens from.
  # Every GitHub Actions job gets a token signed by this URL.
  url = "https://token.actions.githubusercontent.com"

  # "audience" — who is this token intended for?
  # "sts.amazonaws.com" means: this token is for AWS's Security Token Service.
  # STS is the AWS service that hands out temporary credentials.
  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint = a fingerprint of GitHub's SSL certificate.
  # AWS uses this to verify the token is genuinely from GitHub (not a fake).
  # This value comes directly from GitHub's official documentation.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}


# ── STEP 2: IAM Role for DEV ──────────────────────────────────────────────────
#
# An IAM Role is like a badge that grants permissions inside AWS.
# GitHub Actions "wears" this badge when it runs Terraform for dev.
#
# The trust policy (assume_role_policy) answers ONE question:
#   WHO is allowed to pick up and use this badge?
#
# For dev: any branch of your repo can use it.
# Why? Pull Requests run on feature branches. They need the dev role to run
# terraform plan against dev. If you restricted to main-only, PRs would fail.

resource "aws_iam_role" "github_actions_dev" {
  name = "github-actions-dev" # name shown in AWS console

  # The trust policy — defines WHO can assume (use) this role.
  # jsonencode() converts Terraform map syntax into the JSON format AWS expects.
  assume_role_policy = jsonencode({
    Version = "2012-10-17" # AWS policy language version — always this value
    Statement = [
      {
        Effect = "Allow" # allow (not deny) the action below
        Principal = {
          # Federated = "a third party identity system"
          # We trust tokens that come from the GitHub OIDC provider we registered above.
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        # AssumeRoleWithWebIdentity = "use a web token (from GitHub) to get AWS credentials"
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # "aud" = audience — the token must be intended for AWS STS
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # "sub" = subject — who is making the request
            # repo:owner/repo-name:* means any branch, any job in your repo
            # The * wildcard allows: main, feature/anything, PR branches etc.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    managed_by = "terraform"
    purpose    = "github-actions-oidc-dev"
  }
}

# Attach a permission policy to the dev role.
# AdministratorAccess = full AWS admin — can create/delete/modify anything.
# Why full admin for now? When starting out, you do not know exactly which
# permissions Terraform needs. Start broad, tighten later once you know.
# In production companies, this would be replaced with a minimal policy.
resource "aws_iam_role_policy_attachment" "github_actions_dev" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


# ── STEP 3: IAM Role for PROD ─────────────────────────────────────────────────
#
# Same concept as dev role, but with a MUCH stricter trust policy.
#
# For prod: ONLY the main branch can use this role.
# Why? You do not want a feature branch or a PR to accidentally modify prod.
# Even if someone pushes bad code to a feature branch, they cannot touch prod.
# The only way to reach prod is: PR approved → merged to main → apply runs.

resource "aws_iam_role" "github_actions_prod" {
  name = "github-actions-prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            # "sub" here uses StringEquals (exact match) instead of StringLike (wildcard).
            # ref:refs/heads/main = EXACTLY the main branch — nothing else.
            # A PR branch like "feature/add-vpc" does NOT match this → access denied.
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    managed_by = "terraform"
    purpose    = "github-actions-oidc-prod"
  }
}

# Same full admin for prod role.
# Tighten this in the future once you know exactly what Terraform needs.
resource "aws_iam_role_policy_attachment" "github_actions_prod" {
  role       = aws_iam_role.github_actions_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
