# step_6

## Goal

Replace the AWS-specific `/config/localstack.env` generation with a DevStack/OpenStack-friendly dotenv file containing the key endpoints and credentials consumers need.

## Rationale

Downstream components typically want a simple env file. Using `local_file` preserves the existing pattern while switching to OpenStack-derived values (LB IP, DB endpoint, Swift container names).

## Alternatives

- Only expose Terraform outputs: clean, but consumers often prefer `.env` files.
- Write to a fixed absolute path: easy but less portable across machines.
