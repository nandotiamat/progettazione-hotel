## Goal
Create a new OpenStack-focused Terraform root module in `output/` with a pinned OpenStack provider and `clouds.yaml`-based auth.

## Rationale
Keeping OpenStack code isolated in `output/` avoids touching the existing AWS/LocalStack Terraform while still producing a standalone root module that can be `terraform init/validate/plan`'d against DevStack. Using `provider "openstack" { cloud = var.os_cloud }` aligns with `clouds.yaml` and avoids hardcoding credentials.

## Alternatives
- Put OpenStack resources into the existing root module: rejected because it would mix AWS and OpenStack providers/resources and increase risk of accidental applies.
- Inline auth variables (username/password/auth_url) in Terraform: rejected because it increases secret-handling surface area and conflicts with the requirement to use `clouds.yaml`.
