# AGENTS.md — Coding Agent Guidelines for Terraform (LocalStack)

## Project Overview

This is the Terraform infrastructure directory for a full-stack hotel application.
All resources target **LocalStack** (local AWS emulation) and are applied automatically
via the LocalStack Terraform Init Hook when `docker compose up` runs from the repo root.
There are no remote environments, no CI/CD, and no remote backend.

The infrastructure is a flat root module (no submodules) covering: VPC/networking,
ALB + ASG compute, S3 + RDS storage, IAM, Cognito identity, API Gateway, and CloudFront.

---

## Build / Deploy / Test Commands

### Applying Infrastructure

There is no standalone `terraform apply` workflow. Infrastructure is applied by LocalStack
automatically on container startup:

```bash
# From repo root (not this directory)
docker compose up
```

LocalStack mounts `./terraform` as an init hook and runs `tflocal init && tflocal apply`.

### Manual Terraform Commands (if needed)

```bash
# Initialize
tflocal init

# Plan changes
tflocal plan

# Apply changes
tflocal apply -auto-approve

# Destroy
tflocal destroy -auto-approve
```

Use `tflocal` (LocalStack wrapper), not `terraform` directly.

### Formatting

```bash
terraform fmt           # Format all .tf files
terraform fmt -check    # Check formatting without modifying
```

### Validation

```bash
terraform validate      # Validate configuration syntax
```

### No Tests or Linting

There are no test files, no testing framework (no Terratest, no tftest), no linter
config (no tflint, checkov, tfsec), and no pre-commit hooks. If adding tests in the
future, use Terraform's native test framework (`.tftest.hcl` files).

---

## File Organization

Files are split by **infrastructure domain**, not the typical `main.tf/variables.tf/outputs.tf`
per-module pattern:

| File                        | Contents                                          |
|-----------------------------|---------------------------------------------------|
| `main.tf`                   | `terraform` block, provider config, dotenv file generation |
| `variables.tf`              | All input variable declarations (centralized)     |
| `network.tf`                | VPC, subnets, IGW, route tables, Route53, data sources |
| `compute.tf`                | ALB, ASG, launch templates, EC2, CloudWatch alarms |
| `storage.tf`                | S3 buckets, RDS, DB seeding, media seed locals    |
| `security.tf`               | Security groups (ALB, EC2, DB, debug rules)       |
| `iam.tf`                    | IAM roles, policies, instance profiles            |
| `identity.tf`               | Cognito user pool, client, groups, domain         |
| `gateway.tf`                | API Gateway v2 (HTTP), authorizer, routes         |
| `frontend_distribution.tf`  | CloudFront distribution                           |

**Outputs are co-located** with their resources at the bottom of each domain file,
separated by a `# --- OUTPUTS ---` comment. Do NOT create a separate `outputs.tf`.

Non-Terraform files (SQL schema, seed images) live in the sibling `../terraform_content/`
directory and are referenced via `${path.module}/...` paths.

---

## Code Style Guidelines

### Naming Conventions

- **Terraform identifiers** (resources, variables, locals, outputs): `snake_case`
  - Resources: `aws_vpc.main`, `aws_subnet.public_1`, `aws_security_group.alb_sg`
  - Variables: `aws_region`, `db_password`
  - Outputs: `vpc_id`, `alb_dns_name`

- **AWS resource names** (`name` attribute): kebab-case with `myapp-` prefix where appropriate
  - `"myapp-load-balancer"`, `"myapp-target-group"`, `"myapp-user-pool"`
  - Security groups: `"alb-security-group"`, `"ec2-security-group"`
  - IAM roles/policies: `snake_case` with domain prefix — `"hotel_backend_role"`
  - S3 buckets: kebab-case with `-local` suffix — `"my-app-frontend-bucket-local"`

### Tags

- Always include a `Name` tag on resources that support it
- Tag keys: PascalCase (`Name`, `Type`)
- Inline format for simple cases: `tags = { Name = "main-vpc" }`
- Subnets also use a `Type` tag (`"Public"` or `"Private"`)

### Comments

- **Section headers**: `# --- SECTION NAME ---`
- **Comments are in Italian** (this is a project convention — maintain it)
- Use inline `#` comments for explanatory context
- Use `/* ... */` block comments for architectural explanations at end of files
- Use block comment headers for file-level documentation:
  ```hcl
  /* ------------------------------------------------------------------------
     Descrizione del dominio di questo file.
     ------------------------------------------------------------------------ */
  ```

### Variables

- Declare all variables in `variables.tf` (centralized, not per-file)
- Always include `description`, `type`, and `default`
- Only `string` types are currently used — keep types simple
- All variables must have defaults (required by LocalStack's auto-apply init hook)
- Quote variable names: `variable "name" { ... }` (not `variable name { ... }`)

### Provider Configuration

- Single provider: `hashicorp/aws` version `~> 5.0`
- All endpoints hardcoded to `http://localhost:4566` (LocalStack)
- Credentials: `access_key = "test"`, `secret_key = "test"` (LocalStack convention)
- No backend block (local state only)

### IAM Policies

- Use `jsonencode()` for all IAM policy documents and S3 bucket policies
- Do NOT use `aws_iam_policy_document` data sources — this project uses inline JSON

### Formatting

- Use `terraform fmt` standard formatting
- Align `=` signs within blocks where practical
- Separate logical sections with blank lines
- Place `depends_on` at the end of resource blocks

### Resource References

- Reference other resources directly: `aws_vpc.main.id`, `aws_security_group.alb_sg.id`
- All `.tf` files share the same root module namespace — no module prefixes needed
- Use `depends_on` only when implicit dependencies are insufficient

### Iteration

- Prefer `for_each` over `count` for collections
- Use `locals` blocks for defining maps used in `for_each`

### Key Patterns

- **Dotenv generation**: `main.tf` uses `local_file` to write a `.env` file at
  `/config/localstack.env` containing infrastructure outputs for backend/frontend
- **Heredoc strings**: Use `<<-EOF` for `user_data` and multi-line content
- **DB seeding**: `null_resource` with `local-exec` provisioner + `triggers` for
  change detection via `filemd5()`

### Error Handling

- No `validation` blocks, `precondition`, or `postcondition` blocks are currently used
- No `lifecycle` blocks are currently used
- When adding new variables with constraints, prefer `validation` blocks

---

## Important Constraints

1. **LocalStack only** — Do not add production AWS configurations, remote backends,
   or assume real AWS credentials
2. **No modules** — All resources are in the flat root module; do not introduce
   module abstractions without explicit request
3. **Italian comments** — Maintain the existing Italian comment convention
4. **Outputs in domain files** — Keep outputs co-located with their resources,
   not in a separate file
5. **All variables need defaults** — The LocalStack init hook auto-applies without
   `.tfvars` files
