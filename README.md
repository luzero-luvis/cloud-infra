# cloud-infra

Production-grade Terraform infrastructure with automated CI/CD, security scanning, and PR-based review workflow.

---

## How the full flow works

```
YOU (engineer)
│
│  1. write terraform code on your laptop
│  2. push to a feature branch
│  3. open a Pull Request → main
│
└──► GITHUB ACTIONS starts automatically (pr.yml)
          │
          │  Fresh Linux machine spins up
          │  Your code is downloaded onto it
          │
          ▼
    ┌─────────────────────────────────────┐
    │  JOB 1 — fmt & validate             │
    │  (runs for dev AND prod together)   │
    │                                     │
    │  terraform fmt -check               │
    │    "is the code properly indented?" │
    │                                     │
    │  terraform validate                 │
    │    "is the syntax correct?"         │
    └──────────────┬──────────────────────┘
                   │ PASS
          ┌────────┴────────┐
          │                 │
          ▼                 ▼
    ┌───────────┐     ┌───────────────────────────────────┐
    │ JOB 2     │     │ JOB 3                             │
    │ tflint    │     │ checkov                           │
    │           │     │                                   │
    │ checks:   │     │ security scan — checks:           │
    │ - naming  │     │ - SSH open to internet?           │
    │ - unused  │     │ - S3 bucket public?               │
    │   vars    │     │ - encryption missing?             │
    │ - wrong   │     │ - IAM wildcard permissions?       │
    │   types   │     │ - required tags present?          │
    └─────┬─────┘     └──────────────────┬────────────────┘
          │ PASS                         │ PASS
          └────────────┬─────────────────┘
                       │ BOTH must pass
                       ▼
          ┌────────────────────────────────────┐
          │  JOB 4 — terraform plan (dev only) │
          │                                    │
          │  Note: prod plan runs post-merge   │
          │  The prod IAM role only trusts the │
          │  main branch, not PRs              │
          │                                    │
          │  1. GitHub gets OIDC token         │
          │     (signed proof of identity)     │
          │                                    │
          │  2. GitHub sends token to AWS      │
          │     "I am luzero-luvis/cloud-infra"│
          │                                    │
          │  3. AWS checks:                    │
          │     - do I trust GitHub?  ✅       │
          │     - is it the right repo? ✅     │
          │     - gives temp credentials       │
          │       (expires in 1 hour)          │
          │                                    │
          │  4. terraform init                 │
          │     connects to S3                 │
          │     downloads state file           │
          │                                    │
          │  5. terraform plan                 │
          │     asks AWS: what would change?   │
          │     saves output to plan.txt       │
          │                                    │
          │  6. posts plan as PR comment 💬    │
          │     reviewer sees exact changes    │
          └────────────────────────────────────┘
                       │
                       ▼
          ┌────────────────────────────────────┐
          │  HUMAN REVIEW                      │
          │                                    │
          │  Engineer looks at PR:             │
          │  - all checks green? ✅            │
          │  - plan output looks correct? ✅   │
          │  - nothing unexpected destroyed?   │
          │                                    │
          │  If yes → Approve + Merge          │
          │  If no  → Request Changes          │
          └────────────────────────────────────┘
                       │ MERGED to main
                       ▼
          GITHUB ACTIONS starts again (apply.yml)
                       │
                       ▼
          ┌────────────────────────────────────┐
          │  JOB 1 — apply dev                 │
          │                                    │
          │  1. OIDC login → AWS dev role      │
          │  2. terraform init (get state)     │
          │  3. terraform apply                │
          │     → real resources created in   │
          │       AWS dev account              │
          │  4. state file saved back to S3    │
          └──────────────┬─────────────────────┘
                         │ SUCCESS
                         ▼
          ┌────────────────────────────────────┐
          │  ⏸ PAUSE — waiting for approval   │
          │                                    │
          │  GitHub sends notification to      │
          │  the required reviewers            │
          │                                    │
          │  Reviewer opens GitHub UI          │
          │  clicks "Approve deployment"       │
          └──────────────┬─────────────────────┘
                         │ APPROVED
                         ▼
          ┌────────────────────────────────────┐
          │  JOB 2 — apply prod                │
          │                                    │
          │  1. OIDC login → AWS prod role     │
          │     (only main branch can do this) │
          │  2. terraform init (get state)     │
          │  3. terraform apply                │
          │     → real resources created in   │
          │       AWS prod account             │
          │  4. state file saved back to S3    │
          └────────────────────────────────────┘
                         │
                         ▼
                    DONE ✅
```

---

## Where everything lives

```
S3 (state storage — your files, not GitHub's)
├── cloud-infra-tfstate-dev-952933884165
│   ├── dev/terraform.tfstate       ← encrypted state file
│   └── dev/terraform.tfstate.tflock ← lock file (exists only while apply runs)
│
└── cloud-infra-tfstate-prod-952933884165
    ├── prod/terraform.tfstate
    └── prod/terraform.tfstate.tflock

GitHub Secrets (never visible after saving)
├── AWS_ROLE_DEV   → IAM role ARN for dev
└── AWS_ROLE_PROD  → IAM role ARN for prod

GitHub Variables (visible, not secret)
└── AWS_REGION        → us-east-1
```

---

## Repo structure

```
.
├── .github/workflows/
│   ├── pr.yml       ← runs on every PR: fmt, validate, tflint, checkov, plan
│   └── apply.yml    ← runs on merge to main: apply dev → approval → apply prod
├── envs/
│   ├── dev/         ← dev environment terraform code
│   └── prod/        ← prod environment terraform code
├── modules/
│   └── vpc/         ← reusable VPC module
├── bootstrap/       ← one-time setup: S3 buckets + OIDC + IAM roles
├── policies/        ← custom Checkov security policies
├── .checkov.yaml    ← Checkov config (severity threshold, custom policy path)
└── .tflint.hcl      ← TFLint config (naming rules, AWS ruleset)
```

---

## Security layers

| Layer | Tool | What it catches |
|-------|------|----------------|
| Formatting | terraform fmt | Inconsistent indentation |
| Syntax | terraform validate | Typos, wrong resource names |
| Best practices | TFLint | Wrong instance types, deprecated args, unused vars |
| Security | Checkov | Open ports, missing encryption, wildcard IAM, public S3 |
| Auth | OIDC | No static keys — GitHub proves identity to AWS |
| State | S3 AES256 | State file encrypted at rest (S3-native) |
| Approval | GitHub Environments | Human must approve before prod deploy |

---

## GitHub setup checklist

**Secrets** (Settings → Secrets and variables → Actions):
- `AWS_ROLE_DEV` — `arn:aws:iam::952933884165:role/github-actions-dev`
- `AWS_ROLE_PROD` — `arn:aws:iam::952933884165:role/github-actions-prod`

**Variables**:
- `AWS_REGION` — `us-east-1`

**Environments** (Settings → Environments):
- `dev` — optional reviewers
- `production` — required reviewers (workflow pauses until approved)

**Branch protection** (Settings → Branches → main):
- Require pull request before merging
- Require status checks: `fmt & validate`, `tflint`, `checkov`, `terraform plan`
- Require at least 1 approval

---

## Local development

```bash
# run bootstrap once to create S3 buckets and IAM roles
cd bootstrap && terraform init && terraform apply

# work on dev environment
cd envs/dev && terraform init && terraform plan
```
