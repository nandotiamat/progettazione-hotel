# Agent Guide (Terraform / LocalStack)

This folder is a Terraform root module that provisions an AWS-like stack against LocalStack (endpoints are hardcoded in `main.tf`).

## Commands

### Setup

- Init providers/plugins (required before validate/plan/apply):
  - `terraform init`
- If you have multiple Terraform versions installed, prefer pinning via your version manager; this repo currently runs fine with Terraform 1.x.

### Format ("lint" for HCL)

- Format all files in this folder:
  - `terraform fmt -recursive`
- Check formatting in CI-style mode:
  - `terraform fmt -check -recursive`
- Format a single file:
  - `terraform fmt compute.tf`

### Validate

- Validate configuration (requires `terraform init` first):
  - `terraform validate`
- Troubleshooting:
  - If you see "Missing required provider", run `terraform init`.

### Plan / Apply

- Create an execution plan:
  - `terraform plan`
- Plan with an output file (safer apply):
  - `terraform plan -out tfplan`
  - `terraform apply tfplan`
- Destroy (local/dev only):
  - `terraform destroy`

### Lint / Security (optional tools)

These are not required by the repo, but are useful if installed.

- `tflint`:
  - `tflint --init`
  - `tflint`
- `tfsec`:
  - `tfsec .`
- `checkov`:
  - `checkov -d .`

### "Single test" equivalent

Terraform doesn't have native per-test execution in this repo. Use targeted checks instead:

- Check a single file is formatted: `terraform fmt -check compute.tf`
- Validate the module: `terraform validate`
- Narrow plan scope to one resource (use sparingly; can hide dependency issues):
  - `terraform plan -target=aws_s3_bucket.frontend_bucket`

## LocalStack Notes

- `provider "aws"` in `main.tf` is configured for LocalStack:
  - `access_key`/`secret_key` are dummy values.
  - `skip_*` flags are enabled.
  - Service endpoints are mapped to `http://localhost:4566`.
- The configuration assumes LocalStack is running locally and reachable on port 4566.
- S3 uses path-style access (`s3_use_path_style = true`) to avoid DNS issues.

## Repo Layout (what lives where)

- Networking and VPC/subnets/DNS: `network.tf`
- Security groups and debug rules: `security.tf`
- Compute (ALB, ASG, launch template, debug instance): `compute.tf`
- API Gateway v2 + Cognito authorizer + routes: `gateway.tf`
- Cognito user pool/client/domain/groups: `identity.tf`
- IAM role/policy/profile for backend: `iam.tf`
- S3 buckets + CloudFront + RDS instance: `storage.tf`, `frontend_distribution.tf`
- Variables: `variables.tf`
- Local file generation (dotenv for other components): `main.tf`

## Code Style Guidelines (Terraform)

### Formatting

- Always run `terraform fmt` before committing.
- Use 2-space indentation (Terraform fmt enforces this).
- Prefer trailing commas in multi-line lists/objects only when `fmt` keeps them; otherwise follow `fmt` output.

### Naming

- Resource names: `aws_<type>.<logical_name>` where logical names are snake_case and describe purpose:
  - Good: `aws_security_group.alb_sg`, `aws_s3_bucket.media_bucket`
  - Avoid: `thing1`, `test`, or names that encode environment unless necessary.
- Use consistent prefixes for related resources (e.g., `app_` for ALB/ASG/launch template resources).

### Ordering / Structure

- Keep related resources in the same file (this repo already groups by domain).
- Within a file, order blocks roughly:
  - data sources
  - locals
  - resources (core first, then attachments/policies, then outputs)
  - outputs
- Keep long explanatory comments only where they add value; prefer concise comments near non-obvious LocalStack workarounds.

### Variables and Defaults

- Put variables in `variables.tf` with `type` and `description`.
- Prefer no defaults for secrets in real AWS; for LocalStack, defaults are acceptable.
- Mark secrets as `sensitive = true` when introducing new secret variables.
- Use `validation {}` blocks for user-provided inputs when constraints are known.

### Provider / Regions

- This repo currently hardcodes region to `us-east-1` in `main.tf` and uses `var.aws_region` in a few places.
- If you refactor region handling, keep LocalStack endpoint mapping working and avoid introducing real AWS calls unless explicitly requested.

### Dependencies and "gotchas"

- Use implicit dependencies via references (preferred). Add `depends_on` only when required (e.g., provisioners, ordering quirks).
- Avoid `-target` in normal workflows; use it only for debugging or recovery.
- Be careful with `null_resource` and `local-exec`:
  - They run on the machine executing Terraform.
  - They are sensitive to timing and external binaries (`psql`, LocalStack port mappings).

### Error Handling / Safety Patterns

- Prefer Terraform-native checks over scripts:
  - `precondition` / `postcondition` blocks
  - `validation` blocks for variables
- For resources that are expensive/critical in real AWS, consider:
  - `lifecycle { prevent_destroy = true }` (only if the repo expects it)
  - explicit `timeouts {}` when APIs are slow/flaky

### Security

- Do not commit real credentials, tokens, or `.env` files.
- LocalStack dummy credentials are fine, but keep them clearly labeled as such.
- Keep buckets/private data private by default unless the use-case is static hosting.

## Change Workflow

- Before changes: `terraform init` (if providers not installed).
- While editing: run `terraform fmt` frequently.
- Before PR: `terraform fmt -check -recursive` and `terraform validate`.
