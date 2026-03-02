# Full Plan: OpenStack (DevStack) Target Terraform

This plan assumes the DevStack node already has Neutron (OVN), Octavia (OVN provider), Swift, Keystone, Glance, and Nova installed/enabled (per the provided `local.conf`). The work here is to write the missing Terraform configuration that provisions the required 3-tier stack on top of that environment.

## 0) Baseline Checks (DevStack Already Installed)
- Confirm `clouds.yaml` is present and the intended cloud entry exists (e.g., `devstack`).
- Confirm these APIs are reachable and healthy from where Terraform will run:
  - Keystone v3, Glance, Nova, Neutron, Octavia, Swift.
- Capture required “environment facts” that Terraform will need as inputs (no hardcoding):
  - External network name (DevStack commonly uses `public`).
  - External network floating IP pool behavior.
  - Default project/tenant name and domain.
  - Available `cirros` image name/ID.
- Identify any quota constraints (instances, ports, FIPs, LBs) to avoid failed applies.

## 1) Repository Layout (Keep AWS/LocalStack Intact)
- Add a new root module under `openstack/` (do not modify the existing AWS files except docs/ignore rules).
- Proposed structure:
  - `openstack/versions.tf`
  - `openstack/provider.tf`
  - `openstack/variables.tf`
  - `openstack/network.tf`
  - `openstack/security.tf`
  - `openstack/compute.tf`
  - `openstack/lb.tf`
  - `openstack/storage_identity.tf`
  - `openstack/env_file.tf`
  - `openstack/outputs.tf`
  - `openstack/cloud-init/` (templates)
  - `openstack/seed_media/` (assets to upload)
  - `openstack/README.md` (runbook)

## 2) Terraform + Provider Contract (Latest Possible)
- Pin Terraform to a modern 1.x constraint.
- Pin OpenStack provider to the latest available major/minor that supports:
  - Glance v2 images (`openstack_images_image_v2`)
  - Neutron networking/security (`openstack_networking_*_v2`)
  - Nova instances/keypairs (`openstack_compute_*_v2`)
  - Octavia LBaaS v2 (`openstack_lb_*_v2`)
  - Swift object storage (`openstack_objectstorage_*_v1`)
  - Keystone identity (`openstack_identity_*_v3`)
- Provider authentication:
  - Use `clouds.yaml` via `cloud = var.os_cloud`.
  - No secrets in `.tf` files.

## 3) Inputs (Variables) Needed for DevStack Portability
Define variables for the values that are DevStack-specific or environment-dependent:
- `os_cloud` (clouds.yaml entry name)
- `external_network_name`
- `private_net_cidr` (default `10.0.1.0/24`)
- `private_net_name` (default `hotel-private-net`)
- `router_name` (default `hotel-router`)
- `dns_nameservers` (optional)
- `ssh_private_key_path` (default `~/.ssh/hotel-key.pem`)
- `jammy_image_name` (default `hotel-jammy`)
- `jammy_image_source_url` (URL Glance can fetch; required)
- `cirros_image_name` (default `cirros`)
- Optional: `availability_zone`, `keypair_name`, `project_name` (if needed for role assignment)

## 4) Glance: Jammy Cloud Image (Missing Resource)
- Create a Glance image resource for `jammy-server-cloudimg-amd64.img` using `image_source_url`.
- Set a deterministic name; ensure the image is usable by cloud-init instances.
- Add a data lookup for the existing Cirros image for bastion.

## 5) Nova: Flavor, Keypair, and Instance Definitions (Missing Resources)
### 5.1 Flavor
- Create custom flavor `hotel_flavor` with:
  - vCPUs = 1
  - RAM = 2048MB
  - Disk = 10GB

### 5.2 SSH Access
- Generate an SSH keypair:
  - `tls_private_key` for key material.
  - `openstack_compute_keypair_v2` to register the public key.
  - `local_file` to write the private key to `ssh_private_key_path` with strict perms.
- Do not output private key material.

### 5.3 Instances and Ports
- Use explicit Neutron ports per instance so security groups are unambiguous and fixed IPs are easy to reference.
- Create these instances on the private network:
  - `frontend[0..1]` (Jammy)
  - `backend` (Jammy)
  - `db` (Jammy)
  - `bastion` (Cirros)
- Floating IPs:
  - Allocate/associate a floating IP only to bastion.
  - No floating IPs for internal nodes.

## 6) Cloud-init Assets (Missing Files)
Create the required cloud-init configs (templates where indexing/secrets are needed):

### 6.1 `frontend-init-node.yaml`
- Install a simple HTTP server (prefer nginx).
- Serve exactly: `Frontend node {i}` on port 80 (index is Terraform instance index).

### 6.2 `backend-init-node.yaml`
- Install Python + FastAPI + an ASGI server.
- Write a minimal FastAPI app.
- Run it on port 80 via systemd so it survives reboots.

### 6.3 `cloud-init-db.yaml`
- Install PostgreSQL.
- Initialize:
  - Create DB user
  - Create database
  - Grant privileges
- Configure PostgreSQL to accept connections only as needed (backend-only) and bind on the private interface.

Implementation detail:
- Use `templatefile()` and pass rendered YAML as `user_data`.
- Inject generated secrets (DB password, etc.) into user_data safely (not as outputs).

## 7) Neutron Networking (Missing Resources)
Implement the required topology:
- Private network: `hotel-private-net`.
- Subnet: `10.0.1.0/24`.
- Router: `hotel-router`.
- Router external gateway: set to `external_network_name`.
- Router interface: attach private subnet.

Goal: all instances must have outbound internet (package installs) via router SNAT.

## 8) Neutron Security Groups (Missing Resources)
Implement strict segmentation using security group rules with remote group references:

- Bastion SG:
  - Ingress TCP/22 from `0.0.0.0/0`.
  - Egress allow all.

- Frontend SG:
  - Ingress TCP/80 (HTTP) (public-facing via LB; if required, allow `0.0.0.0/0`).
  - Ingress TCP/22 only from Bastion SG (remote group).
  - Egress allow all.

- Backend SG:
  - Ingress TCP/80 for API (match requirement).
  - Ingress TCP/22 strictly from Frontend SG (remote group).
  - Egress allow all.

- Database SG:
  - Ingress TCP/5432 strictly from Backend SG (remote group).
  - Egress allow all.

Attach SGs to instance ports:
- Bastion port: Bastion SG.
- Frontend ports: Frontend SG.
- Backend port: Backend SG.
- DB port: DB SG.

## 9) Octavia (OVN) L4 Load Balancer (Missing Resources)
Provision the L4 LB strictly at TCP level:
- Load balancer `hotel-lb` with `loadbalancer_provider = "ovn"`.
- VIP on the private subnet.
- Listener: TCP port 80.
- Pool:
  - Protocol TCP
  - Algorithm/method `SOURCE_IP_PORT`
- Members: the two frontend fixed IPs, port 80.
- Health monitor:
  - Type TCP
  - delay 5s
  - timeout 3s
  - max retries 3

Public exposure:
- Allocate a floating IP and associate it to the LB VIP port.
- Result: only the LB VIP and bastion are public.

## 10) Swift + Keystone IAM/ACLs + Seeding (Missing Resources)

### 10.1 Container
- Create Swift container `hotel-assets`.

### 10.2 Keystone Roles + Users
- Create Keystone roles:
  - `media_reader`
  - `media_uploader`
- Create Keystone users:
  - `app_frontend_reader`
  - `app_frontend_uploader`
- Assign roles to users in the target project.
- Generate user passwords using `random_password` and never output them.

### 10.3 Container ACLs
- Apply read/write ACLs on `hotel-assets` so:
  - `media_reader` can read
  - `media_uploader` can write
- Implement in a DevStack-compatible way for Swift+Keystone auth (role/user-based ACL strings as required by Swift).

### 10.4 Seeding Media
- Create `openstack/seed_media/` in-repo.
- Upload `.png/.jpg/.jpeg` assets found in that folder into `hotel-assets`.
- Use `fileset()` so Terraform automatically tracks additions/removals.
- Set `content_type` based on file extension.

## 11) Secrets + Local `.env` Generation (Missing Resources)
- Generate all required secrets via Terraform resources (e.g., DB password, Keystone user passwords).
- Generate a local `.env` file with `local_file` containing:
  - Bastion floating IP
  - LB floating IP
  - DB host (private IP), port, dbname, username, password
  - Swift container name
  - Swift/Keystone user credentials needed by apps (only in the `.env`, not outputs)
- Ensure `.env` and the SSH private key path are gitignored.

## 12) Dependency and Ordering Strategy
- Explicitly link resources through references to ensure correct ordering:
  - Router interface depends on subnet/router.
  - Instance ports depend on network+subnet.
  - Instances depend on keypair and image.
  - LB members depend on instance ports/addresses.
  - Floating IP associations depend on their ports existing.
- Avoid `null_resource` and `local-exec` for core provisioning; only use if Swift ACLs or seeding require a provider gap (prefer native resources first).

## 13) Validation and Test Procedure
- In `openstack/`:
  - `terraform fmt -recursive`
  - `terraform init`
  - `terraform validate`
  - `terraform plan`
  - `terraform apply`
- Post-apply functional checks:
  - From the internet/host: SSH to bastion via floating IP.
  - From bastion: SSH into private instances using internal IPs.
  - From the internet/host: curl the LB floating IP on port 80; confirm it returns `Frontend node 0/1` across requests.
  - From backend: connect to DB on 5432.
  - Swift: verify container exists and seeded objects are present.

## 14) Documentation (Runbook)
- Add `openstack/README.md` documenting:
  - Required variables and example `terraform.tfvars` (no secrets committed).
  - How to confirm external network name.
  - Expected outputs.
  - Common DevStack troubleshooting for Octavia OVN provider.

## Deliverables
- `openstack/` Terraform root module implementing all required OpenStack resources.
- Cloud-init templates under `openstack/cloud-init/`.
- Seed directory `openstack/seed_media/` (empty by default, populated by user/repo).
- Local `.env` generation and gitignore protections.
