## Goal
Provision Swift + Keystone IAM and automate asset seeding: create the `hotel-assets` container, create roles/users, bind roles to users in a project, apply container read/write ACLs, and upload any `.png/.jpg/.jpeg` files found under `seed_media/`.

## Rationale
Using `openstack_identity_role_v3`, `openstack_identity_user_v3`, and `openstack_identity_role_assignment_v3` provides Terraform-managed RBAC primitives. Swift container ACLs are applied via `container_read`/`container_write` on `openstack_objectstorage_container_v1`. Seeding is implemented with `fileset()` discovery so adding/removing assets does not require Terraform code changes.

## Alternatives
- Manage Swift ACLs via `metadata` headers only: rejected because the provider exposes explicit `container_read`/`container_write` fields which are clearer and more portable.
- Upload assets via `null_resource` + `openstack` CLI: rejected because it adds external tooling dependencies and is harder to keep idempotent.
