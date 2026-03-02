## Goal
Add cloud-init templates for the frontend, backend, and database nodes.

## Rationale
Using `#cloud-config` templates rendered by Terraform via `templatefile()` keeps per-role bootstrapping declarative, repeatable, and compatible with Ubuntu cloud images. Nginx provides a minimal HTTP server for the frontend, FastAPI+uvicorn provides a minimal backend on port 80, and PostgreSQL is initialized via an idempotent SQL script driven by Terraform-generated credentials.

## Alternatives
- Use configuration management (Ansible/Chef) post-provision: rejected because requirements explicitly call for cloud-init configs.
- Run backend/db initialization purely via `runcmd` shell without files/systemd: rejected because a systemd unit is more reliable across reboots and file-based configuration is easier to inspect.
