# Step 2: variables.tf — Variabili Centralizzate

## Goal

Define all input variables for the OpenStack infrastructure in a single centralized file. Every variable includes `description`, `type`, and `default` so the configuration can be applied automatically without `.tfvars` files.

## Rationale

Following the project convention from AGENTS.md, all variables are centralized in `variables.tf` rather than scattered across domain files. All variables have defaults to allow auto-apply (matching the LocalStack init hook convention carried over to DevStack). The `db_password` is marked `sensitive = true` to prevent it from appearing in CLI output. A `cloud` variable is included to select the cloud name from `clouds.yaml`, defaulting to `"devstack"`.

## Alternatives

1. **Per-file variable declarations** -- Would scatter variable definitions across domain files. Rejected per AGENTS.md convention requiring centralization.
2. **No defaults on sensitive variables** -- Would require interactive input or `.tfvars` files. Rejected because the auto-apply pattern requires defaults.
3. **Using environment variables instead of `clouds.yaml`** -- The OpenStack provider supports `OS_*` environment variables, but `clouds.yaml` is cleaner and was specified in the requirements.
