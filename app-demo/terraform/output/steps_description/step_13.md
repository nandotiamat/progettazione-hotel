# Step 13: Variables (`variables.tf`)

## Goal

Finalize the centralized `variables.tf` with all OpenStack-specific input variables, replacing AWS variables (`aws_region`) and adding new ones for DevStack authentication, compute images, and flavors.

## Rationale

All variables follow the original project's convention: each has `description`, `type`, and `default`. All defaults are provided because the configuration must work without `.tfvars` files (matching the original LocalStack constraint).

The final variable set:

| Variable | Replaces | Default |
|----------|----------|---------|
| `os_auth_url` | (new) | `http://192.168.1.13/identity` |
| `os_user_name` | (new) | `admin` |
| `os_password` | (new, sensitive) | `secret` |
| `os_tenant_name` | (new) | `admin` |
| `os_region` | `aws_region` | `RegionOne` |
| `db_password` | `db_password` (kept, sensitive) | `test` |
| `image_name` | (new) | `cirros-0.6.3-x86_64-disk` |
| `flavor_name` | (new) | `m1.small` |

The `sensitive = true` flag was added to `os_password` and `db_password` to prevent them from appearing in plan/apply output, improving security hygiene even in a development environment.

## Alternatives

1. **Using `OS_*` environment variables** — The OpenStack provider can read credentials from standard environment variables (OS_AUTH_URL, OS_USERNAME, etc.). This would eliminate the need for credential variables in `variables.tf`. Rejected to maintain explicit configuration and self-contained Terraform files, consistent with the original design.
2. **Using `clouds.yaml` reference** — A single `cloud` variable referencing a clouds.yaml entry. Cleaner for multi-environment setups but rejected for DevStack simplicity.
3. **Not marking passwords as sensitive** — The original `db_password` wasn't sensitive. Added `sensitive = true` as a minor improvement that doesn't break existing behavior.
