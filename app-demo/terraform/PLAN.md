# Plan: AWS (LocalStack) -> OpenStack (DevStack) Terraform

## Goal
Translate the existing AWS-focused Terraform stack into an equivalent OpenStack Terraform configuration targeting a constrained DevStack (stable/2025.1) environment, using `clouds.yaml` authentication.

## Approach (Non-Destructive)
- Create a new Terraform root module under `openstack/` so the existing AWS/LocalStack configuration remains intact for reference.
- Implement OpenStack resources to match the required 3-tier architecture: Glance image, Nova compute, Neutron networking/security, Octavia (OVN) L4 load balancer, Swift + Keystone IAM/ACLs, and local `.env` generation.

## Step-by-Step Work

### 1) Scaffold a New OpenStack Root Module
- Create `openstack/` with:
  - `openstack/versions.tf`: require latest Terraform 1.x and the latest `terraform-provider-openstack`.
  - `openstack/provider.tf`: `provider "openstack" { cloud = var.os_cloud }` (no hardcoded creds).
  - `openstack/variables.tf`: minimal knobs (e.g., `os_cloud`, `external_network_name`, `dns_nameservers`, `ssh_private_key_path`, `jammy_image_source_url`).
  - `openstack/outputs.tf`: only non-sensitive outputs (e.g., bastion floating IP, LB floating IP).

### 2) Glance: Import Ubuntu Jammy Cloud Image
- Add an `openstack_images_image_v2` resource named like `hotel_ubuntu_jammy`.
- Use `image_source_url` pointing to `jammy-server-cloudimg-amd64.img`.
- Set sane image properties for cloud-init usage (disk/container formats compatible with DevStack/Glance).
- Also add a data source lookup for the existing `cirros` image for the bastion.

### 3) Nova: Flavor, Keypair, and Instances
- Create a custom flavor `hotel_flavor` (1 vCPU, 2048MB RAM, 10GB disk).
- Generate an SSH keypair:
  - `tls_private_key` for key material.
  - `openstack_compute_keypair_v2` named `hotel-keypair` using the generated public key.
  - `local_file` writing the private key to `~/.ssh/hotel-key.pem` (or configurable path) with restrictive permissions.
- Implement instances on the private network:
  - `2x` frontend (Jammy image) with cloud-init.
  - `1x` backend (Jammy image) with cloud-init.
  - `1x` database (Jammy image) with cloud-init.
  - `1x` bastion (Cirros image) with floating IP.
- Prefer explicit Neutron ports per instance to:
  - Attach the right security group(s).
  - Make it easy to reference fixed IPs for LB pool members.

### 4) Cloud-init: Frontend / Backend / DB Config
- Add cloud-init templates under `openstack/cloud-init/`:
  - `openstack/cloud-init/frontend-init-node.yaml.tftpl`
    - Install a lightweight web server (e.g., nginx).
    - Write `/var/www/html/index.html` to exactly `Frontend node ${index}`.
    - Ensure it listens on port 80.
  - `openstack/cloud-init/backend-init-node.yaml`
    - Install Python + packages needed for FastAPI.
    - Create a simple FastAPI app and run it on port 80 (systemd unit).
  - `openstack/cloud-init/cloud-init-db.yaml`
    - Install PostgreSQL.
    - Initialize DB/user/database (values injected from Terraform-generated secrets).
    - Configure `listen_addresses` and `pg_hba.conf` to allow connections only from the private subnet / backend.
- Render templates via `templatefile()` and pass as instance `user_data`.

### 5) Neutron Networking: Private Network + Router + Floating IPs
- Create:
  - Network: `hotel-private-net`.
  - Subnet: `10.0.1.0/24` (plus DNS settings as variables).
  - Router: `hotel-router` with external gateway set to the external/public network.
  - Router interface attaching the private subnet.
- Allocate floating IPs from the external network pool and associate them only to:
  - Bastion port.
  - Octavia load balancer VIP port.

### 6) Neutron Security Groups: Strict Segmentation
- Create 4 security groups with explicit rules:
  - `bastion_sg`: ingress TCP/22 from `0.0.0.0/0`; egress allow all.
  - `frontend_sg`: ingress TCP/80 from `0.0.0.0/0`; ingress TCP/22 only from `bastion_sg` (remote group rule); egress allow all.
  - `backend_sg`: ingress TCP/80 from `0.0.0.0/0` (or restrict to frontend if desired by requirement); ingress TCP/22 only from `frontend_sg`; egress allow all.
  - `db_sg`: ingress TCP/5432 only from `backend_sg`; egress allow all.
- Use `remote_group_id` rules (instead of CIDRs) where “strictly from SG” is required.

### 7) Octavia (OVN Provider): L4 TCP Load Balancer
- Provision:
  - `openstack_lb_loadbalancer_v2` named `hotel-lb` with `loadbalancer_provider = "ovn"` and VIP on the private subnet.
  - Listener: TCP/80.
  - Pool: TCP with `lb_method = "SOURCE_IP_PORT"`.
  - Members: the two frontend fixed IPs on TCP/80.
  - Monitor: TCP with delay `5s`, timeout `3s`, max retries `3`.
- Associate a floating IP to the LB VIP port (so the public endpoint is the LB, not the frontends).

### 8) Swift + Keystone IAM + ACLs + Seeding
- Create Swift container `hotel-assets`.
- Create Keystone roles: `media_reader`, `media_uploader`.
- Create Keystone users: `app_frontend_reader`, `app_frontend_uploader`.
- Bind roles to users within the target project/tenant.
- Apply the roles/users to Swift container ACLs (read vs write) in a way compatible with the DevStack Swift+Keystone auth pipeline.
- Seeding:
  - Add `openstack_objectstorage_object_v1` resources to upload initial `.png/.jpg` assets.
  - Implement discovery using `fileset()` over `openstack/seed_media/**/*.{png,jpg,jpeg}` so the repo can add/remove assets without editing Terraform.

### 9) Secrets Handling and `.env` Generation
- Use Terraform-generated secrets (e.g., `random_password` for DB/app creds).
- Do not expose secrets in outputs.
- Generate a local `.env` via `local_file` containing:
  - Bastion floating IP (non-secret) and internal IPs.
  - DB connection details + generated password.
  - Swift container name and any needed auth/usernames (passwords included only in the file).
- Add `.gitignore` updates if needed so generated `.env` and private keys are not committed.

### 10) Validation Workflow
- Run:
  - `terraform fmt -recursive`
  - `terraform init` (inside `openstack/`)
  - `terraform validate`
  - `terraform plan`
- Provide a short runbook in `openstack/README.md` with required vars and typical `openstack` CLI checks (networks, images, Octavia status) to debug DevStack quirks.

## Assumptions / Inputs I’ll Parameterize
- `external_network_name`: name of DevStack external network (often `public`).
- `jammy_image_source_url`: URL reachable by Glance for `jammy-server-cloudimg-amd64.img`.
- Asset seed folder: `openstack/seed_media/` will be created and populated by the repo/user; Terraform will upload whatever is present.

## What Changes Based on Your Approval
- After you approve this plan, I will start creating the `openstack/` module files, cloud-init templates, and supporting Terraform resources.
