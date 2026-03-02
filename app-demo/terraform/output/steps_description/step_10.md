## Goal
Generate a local `.env` file containing the required connection details and generated secrets, while keeping Terraform outputs non-sensitive.

## Rationale
Secrets must not be hardcoded or exposed via outputs. Writing them to a local `.env` via `local_file` satisfies the requirement and gives downstream components a standard way to consume credentials.

## Alternatives
- Output secrets via `sensitive = true` Terraform outputs: rejected because the requirement explicitly prohibits exposing secrets in outputs.
- Require the user to manually create the `.env`: rejected because the requirement calls for Terraform to generate it.
