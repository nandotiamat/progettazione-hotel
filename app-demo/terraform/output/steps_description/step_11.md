# Step 11: IAM (`iam.tf` → merged into `identity.tf`)

## Goal

Map AWS IAM roles, policies, and instance profiles to Keystone roles, merged into `identity.tf` as specified in the plan's file mapping.

## Rationale

OpenStack does not have an equivalent to AWS IAM's fine-grained policy system. The original `iam.tf` defined:

- `aws_iam_role` (hotel_backend_role) with an EC2 assume role policy
- `aws_iam_policy` (S3 access: PutObject, GetObject, ListBucket, DeleteObject)
- `aws_iam_role_policy_attachment` (binding policy to role)
- `aws_iam_instance_profile` (allowing EC2 to assume the role)

In Keystone, roles are simple labels assigned to users on projects/domains. There's no concept of:
- Policy documents with specific action/resource permissions
- Instance profiles for automatic role assumption by VMs
- Trust relationships (assume role policies)

The `hotel_backend_service` role is created as a conceptual marker and assigned to the service user on the application project. In practice, backend instances would authenticate to Swift using Keystone credentials (username/password or application credentials) injected via user_data or environment variables, rather than through automatically assumed roles.

The file was merged into `identity.tf` per the plan's file mapping table, which consolidates `iam.tf` and `identity.tf` into a single file.

## Alternatives

1. **Keystone application credentials** — Creating scoped credentials for the service user that could be injected into VMs. More operational security than a simple role. Rejected because the Terraform OpenStack provider doesn't have a resource for application credentials; they would need to be created via CLI/API post-apply.
2. **Separate `iam.tf` file** — Keeping IAM separate. Rejected because the plan explicitly merges it into `identity.tf`.
3. **Barbican secrets** — Storing credentials in OpenStack's secret manager. Rejected because Barbican is not enabled in this DevStack.
