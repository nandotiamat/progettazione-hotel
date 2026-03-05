# Step 5: Cloud-Init Configurations

## Goal
Generate the `cloud-init` YAML configurations needed to bootstrap our three primary instance types: Frontend, Backend, and Database.

## Rationale
- **Frontend** (`frontend-init-node.yaml`): Simply updates packages, installs `nginx`, and lays down a static HTML file indicating success on port 80.
- **Backend** (`backend-init-node.yaml`): Provisions a Python virtual environment, installs `fastapi`/`uvicorn`, injects a simple app serving JSON on port 80, and configures a systemd service to ensure it runs continuously.
- **Database** (`cloud-init-db.yaml`): Installs PostgreSQL, initializes the `hotel_db` and `hotel_user`, and importantly modifies `postgresql.conf` and `pg_hba.conf` to allow listening on `0.0.0.0` (which is safe here since the Security Group restricts ingress strictly to the backend tier).

## Alternatives
- **Configuration Management tools (Ansible/Chef)**: While more robust for complex state, they introduce higher operational overhead and dependencies compared to simple YAML-based `cloud-init` data injected via Nova metadata, aligning perfectly with a "zero-touch" Terraform migration.
