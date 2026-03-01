# Step 1: Pulizia e Scaffolding

## Goal

Prepare the `output/` directory structure for the new OpenStack Terraform configuration. Create subdirectories for cloud-init templates and step documentation, and establish a symlink to the existing seed media files so they are reachable via `${path.module}/seed_media/`.

## Rationale

Rather than deleting the existing AWS `.tf` files in-place, all new OpenStack Terraform code is written into the `output/` directory. This preserves the original AWS configuration for reference while building the new infrastructure side-by-side. The `seed_media/` symlink avoids duplicating ~17 PNG files and keeps the Terraform `${path.module}/seed_media/` path working naturally from inside the `output/` directory.

## Alternatives

1. **Copy seed_media instead of symlink** -- Would duplicate ~17 files unnecessarily and create a maintenance burden if images change. Rejected in favor of a symlink.
2. **Delete AWS .tf files and write in-place** -- The FULL_PLAN.md originally proposed this approach, but the user chose to write into a separate `output/` directory to preserve the original files.
3. **Use `../terraform_content/seed_media/` directly in Terraform paths** -- Would require non-standard relative paths in the Terraform code (`${path.module}/../terraform_content/seed_media/`), making the module less portable. The symlink keeps paths clean.
