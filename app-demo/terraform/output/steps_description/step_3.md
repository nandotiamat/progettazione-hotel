# Step 3: main.tf (parziale) — Provider e Configurazione Base

## Goal

Define the `terraform` block with all four required providers (`openstack`, `tls`, `local`, `random`) and configure the OpenStack provider to authenticate via `clouds.yaml` with no hardcoded credentials. The `local_file` for `.env` generation is deferred to Step 10 when all resource outputs are available.

## Rationale

- **Provider version constraints** use pessimistic pinning (`~> 3.0`, `~> 4.0`, etc.) to allow patch/minor updates while preventing breaking major version changes. The resolved versions are: openstack 3.4.0, tls 4.2.1, local 2.7.0, random 3.8.1 — all the latest available.
- **`required_version >= 1.6.0`** ensures compatibility with modern Terraform features (templatefile, sensitive variables, etc.) without being overly restrictive.
- **`clouds.yaml` authentication** is the cleanest approach for OpenStack — the provider reads it automatically when `cloud = "devstack"` is set. No `OS_*` environment variables or inline credentials needed.
- The `local_file.dotenv` resource is intentionally omitted at this stage to avoid forward-referencing resources that don't exist yet, allowing incremental `terraform validate`.

## Alternatives

1. **Inline credentials in provider block** — Would hardcode `auth_url`, `user_name`, `password`, etc. Rejected because `clouds.yaml` is cleaner, more secure, and was specified in requirements.
2. **Exact version pinning (e.g., `= 3.4.0`)** — Too restrictive; prevents receiving bugfix releases. Pessimistic pinning provides the right balance.
3. **Including `local_file.dotenv` now** — Would cause validation errors since it references resources not yet defined. Deferred to Step 10.
