# Step 9: Environment Secrets Management

## Goal
Generate a local `.env` file containing critical system outputs, database credentials, swift endpoints, and floating IPs, preventing sensitive information from polluting Terraform CLI outputs.

## Rationale
- **Secret Hygiene**: Injecting credentials (such as the generated passwords for Keystone or the DB user) strictly into a `local_sensitive_file` `.env` restricts file permissions to `0600` and ensures they do not print to standard output during `terraform apply`.
- **Developer Experience**: A unified `.env` file provides immediate utility for local developer scripts or CI/CD pipelines that need to target the newly built architecture.

## Alternatives
- **Standard Output Logs**: Outputting `random_password.result` and IP addresses via standard Terraform `output` blocks exposes them in plaintext to logs and consoles, which violates secure deployment practices.
