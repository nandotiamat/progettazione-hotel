# Step 11: Validazione Finale

## Goal

Run `terraform fmt` and `terraform validate` on the complete configuration to ensure all files are properly formatted and the configuration is syntactically and semantically valid.

## Rationale

- **`terraform fmt -check`** — Verifies all `.tf` files follow the canonical Terraform formatting standard. Exit code 0 confirms no formatting changes are needed.
- **`terraform validate`** — Performs a comprehensive check: syntax parsing, provider schema validation, resource attribute verification, and cross-resource reference resolution. This catches issues like missing required attributes, invalid resource types, or broken references between files.
- Running validation after every step (incrementally) caught one issue early: the `openstack_compute_floatingip_associate_v2` resource was removed in OpenStack provider v3.x and was replaced with `openstack_networking_floatingip_associate_v2` using `port_id` instead of `instance_id`. This was fixed in Step 7.

## Alternatives

1. **`terraform plan`** — Would be a more thorough validation since it contacts the OpenStack API. However, it requires a live DevStack instance and valid `clouds.yaml`, which may not be available on the development machine. `validate` is sufficient for offline verification.
2. **`tflint`** — A Terraform linter that catches additional issues (deprecated syntax, naming conventions, etc.). Not currently configured for this project, as noted in AGENTS.md.
3. **`checkov` / `tfsec`** — Security scanning tools. Not used in this project per AGENTS.md conventions.
