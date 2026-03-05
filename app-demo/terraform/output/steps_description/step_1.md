# Step 1: Provider and Variables Setup

## Goal
Establish the foundational OpenStack provider block and the input variables required to authenticate against the target DevStack environment. This replaces the AWS LocalStack provider configuration.

## Rationale
To ensure the Terraform configuration is natively compatible with OpenStack, `main.tf` was refactored to use `terraform-provider-openstack/openstack` (version ~> 2.1.0). The `variables.tf` file was updated to include DevStack-specific variables (`auth_url`, `tenant_name`, `user_name`, `password`, `region`) defaulting to the local `admin`/`secret` credentials to streamline the transition. The `auth_url` explicitly targets the endpoint defined in the initial plan (`http://192.168.1.13/identity/v3`).

## Alternatives
*   **Alternative considered:** Relying on `OS_` environment variables entirely instead of defining inputs in `variables.tf`.
*   **Why it was not chosen:** Defining the variables explicitly makes the configuration more self-documenting, easier to override per-workspace if needed, and maintains a direct correlation to standard Terraform input practices, even though environment variables remain an option.