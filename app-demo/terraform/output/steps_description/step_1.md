# Step 1: Provider Configuration & Initialization

## Goal
Configure the Terraform environment to use the `terraform-provider-openstack` and set up authentication using OpenStack's `clouds.yaml` mechanism.

## Rationale
Using `clouds.yaml` for authentication allows us to avoid hardcoding sensitive credentials in the Terraform code. It delegates identity management to a secure, standardized configuration file. Defining the OpenStack provider version (`~> 3.0`) ensures stability and prevents breaking changes from future major provider updates.

## Alternatives
- **Hardcoding credentials**: We could have used variables for `username`, `password`, `tenant_id`, and `auth_url` directly in the `provider` block. This was rejected because it's less secure and complicates credential rotation, especially across different environments or developers.
