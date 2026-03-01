# Step 9: storage.tf — Swift, Keystone Identity, Seeding

## Goal

Create the object storage layer and identity management: a Swift container for media assets with ACL-based access control, two Keystone users (reader and uploader) with custom roles and random passwords, role assignments binding users to the project, and seed upload of all 17 media images into the container.

## Rationale

- **`random_password`** for Keystone user credentials — Generates secure 24-character passwords without special characters (to avoid shell escaping issues). Passwords are never exposed as Terraform outputs; they appear only in the `.env` file (Step 10).
- **`data.openstack_identity_project_v3.current`** — Looks up the current project ("demo" in DevStack) to reference its ID for role assignments and Swift ACLs. Using a data source instead of hardcoding the project ID makes the config portable.
- **Custom Keystone roles** (`media_reader`, `media_uploader`) — Provides fine-grained access separation. The reader can only read from the container; the uploader can write. This mirrors the IAM role separation from the original AWS setup.
- **Swift ACLs** use the `project:user` format — This is the standard Swift ACL syntax. The `container_read` and `container_write` attributes on the container resource set the ACLs declaratively.
- **`locals.media_files` map with `for_each`** — Exact same pattern as the original AWS S3 seeding. The keys represent the Swift object paths (e.g., `prop01/front.png`), the values are the local file paths. Content type detection reuses the same `lookup`/`split` logic.

## Alternatives

1. **Using `openstack_identity_application_credential_v3` instead of users** — Application credentials are more scoped, but they're tied to the creating user's lifecycle and can't be managed independently. Dedicated users are cleaner for this use case.
2. **Public container ACL (`.r:*`)** — Would make all objects publicly readable without authentication. Rejected because the original architecture uses authenticated access.
3. **`fileset()` + `for_each` for dynamic file discovery** — Would automatically find all files in `seed_media/`, but loses control over the object key naming (directory structure). The explicit map preserves the `prop01/front.png` hierarchy.
4. **Storing passwords in Vault/Barbican** — Barbican is not enabled in this DevStack instance. `random_password` + `.env` file is the pragmatic alternative for local development.
