# Step 12: Dotenv File Generation (`main.tf`)

## Goal

Update the `local_file.dotenv` resource to output OpenStack-specific values, replacing all AWS/LocalStack references with OpenStack equivalents: Keystone auth URL, Swift container names/URLs, database VM IP, and load balancer VIP.

## Rationale

The original design used `local_file` to generate a `.env` file consumed by the frontend and backend containers. This pattern is preserved but adapted for OpenStack:

- **Cognito values** replaced with Keystone auth URL, project ID/name, and service user name
- **API Gateway endpoint** removed (no equivalent; handled at app level)
- **ALB DNS name** replaced with Octavia LB VIP address
- **S3 bucket names/endpoints** replaced with Swift container names and Swift API URLs
- **RDS endpoint** replaced with DB VM IP + standard PostgreSQL port 5432
- **CloudFront domain/ID** removed (no equivalent)
- **Networking IDs** added (useful for debugging in OpenStack)

The `hashicorp/local` provider was added to `required_providers` since `local_file` requires it.

## Alternatives

1. **Terraform outputs only (no file generation)** — Let the application read outputs via `terraform output`. Rejected to maintain the same deployment pattern where the `.env` file is auto-generated and mounted.
2. **Using `templatefile()` with an external template** — Cleaner for complex templates. Rejected because the inline heredoc is consistent with the original design and the template is small enough.
3. **Generating multiple files** — Separate files for frontend and backend config. Rejected for simplicity and consistency with the single-file original approach.
