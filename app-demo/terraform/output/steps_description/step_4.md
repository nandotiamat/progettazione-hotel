# Step 4: Cloud-Init Files

## Goal

Create three cloud-init configuration files (`cloud-config` format) that will be injected as `user_data` into the Nova instances at boot time:
1. **`frontend-init-node.yaml`** — Installs Nginx and deploys a static HTML page identifying the node index.
2. **`backend-init-node.yaml`** — Installs Python3, creates a FastAPI application, and runs it with Uvicorn on port 80.
3. **`cloud-init-db.yaml`** — Installs PostgreSQL, creates the application user/database, configures remote access from the private subnet, and restarts the service.

## Rationale

- **Terraform `templatefile()`** is used for files needing variable interpolation (frontend: `node_index`; database: `db_user`, `db_password`, `db_name`, `subnet_cidr`). The backend file has no variables and is read with `file()`.
- **PostgreSQL remote access** is configured by modifying both `postgresql.conf` (listen on all interfaces) and `pg_hba.conf` (allow MD5 auth from the subnet CIDR). The `GRANT ALL ON SCHEMA public` command is necessary for PostgreSQL 15+ where the public schema is no longer writable by default.
- **Uvicorn runs with `nohup &`** to detach from the cloud-init process and survive after the init script completes.
- The DB schema SQL (548 lines) is intentionally NOT embedded in cloud-init to keep the file manageable. The database VM is provisioned with connectivity only; the full schema can be applied separately.

## Alternatives

1. **Embedding schema.sql directly in cloud-init** — The 548-line SQL file would make the cloud-init YAML unwieldy. Rejected in favor of provisioning infrastructure only.
2. **Using `runcmd` for Nginx config instead of `write_files`** — `write_files` is the idiomatic cloud-config approach for static content. Preferred for readability.
3. **Running FastAPI on a non-privileged port (e.g., 8000)** — Would require the LB/frontend to target port 8000 instead of 80. Using port 80 keeps the architecture consistent with the original AWS setup.
4. **Using systemd unit files for Uvicorn** — More robust for production, but overkill for a DevStack development environment. `nohup` is simpler.
