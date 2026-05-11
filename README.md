# cloud-infra

Production-grade Terraform infrastructure with automated CI/CD, security scanning, and PR-based review workflow.

## Workflow

```
feature branch  →  Pull Request  →  main  →  AWS
                        │
                  GitHub Actions
                  ─────────────
                  fmt + validate
                  tflint
                  checkov
                  terraform plan  (posted as PR comment)
                        │
                  Senior review
                        │
                  PR approved & merged
                        │
                  GitHub Actions: terraform apply
                  (production requires manual approval gate)
```

## Structure

```
.
├── .github/workflows/
│   ├── pr.yml       # runs on every PR: fmt, validate, tflint, checkov, plan
│   └── apply.yml    # runs on merge to main: apply dev → approval → apply prod
├── envs/
│   ├── dev/         # dev environment
│   └── prod/        # prod environment
├── modules/
│   └── vpc/         # reusable VPC module
├── policies/        # custom Checkov policies (YAML)
├── .checkov.yaml    # Checkov config
└── .tflint.hcl      # TFLint config
```

## Security

- **Checkov** — 1000+ built-in AWS security checks + custom tag enforcement policy
- **TFLint** — naming conventions, deprecated APIs, undocumented variables
- **OIDC** — no long-lived AWS credentials stored in GitHub secrets
- **VPC flow logs** — enabled on all VPCs (CKV2_AWS_11)
- **No public IP auto-assign** on subnets (CKV_AWS_130)

## GitHub Setup

### Secrets required

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_DEV` | IAM role ARN for dev (OIDC) |
| `AWS_ROLE_PROD` | IAM role ARN for prod (OIDC) |

### Variables required

| Variable | Example |
|----------|---------|
| `AWS_REGION` | `us-east-1` |

### Environments

Create two GitHub Environments under **Settings → Environments**:

- `dev` — optional reviewers
- `production` — **required reviewers** (blocks apply until a human approves)

### Branch protection (Settings → Branches → main)

- Require pull request before merging
- Require status checks: `fmt & validate`, `tflint`, `checkov`, `terraform plan`
- Require at least 1 approval
- Do not allow bypassing the above settings

## Local development

```bash
# Install tools
pip install checkov
brew install tflint terraform

# Scan current directory
checkov -d . --config-file .checkov.yaml

# Lint
cd envs/dev && tflint --init && tflint

# Plan (requires AWS credentials)
cd envs/dev && terraform init && terraform plan
```

## State backend

Each environment uses its own S3 bucket + DynamoDB lock table.
Create them before the first `terraform init`:

```bash
# Example for dev
aws s3api create-bucket --bucket cloud-infra-tfstate-dev --region us-east-1
aws dynamodb create-table \
  --table-name cloud-infra-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```
