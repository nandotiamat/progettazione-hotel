# Full Development Plan: OpenStack Terraform Migration

This plan details the exact steps to develop the target OpenStack Terraform scripts based on the constraints and requirements of the DevStack environment. It assumes all DevStack components (Neutron, OVN, Swift, Octavia) are already installed and running.

## Phase 1: Provider & Core Configuration (`main.tf`, `variables.tf`)
1. **Terraform Block:** Configure the `terraform` block to use the latest `terraform-provider-openstack`.
2. **Provider Block:** Configure the `openstack` provider to rely entirely on `clouds.yaml` for authentication, ensuring no credentials are hardcoded.
3. **Variables:** Define necessary variables (e.g., external network name, image URLs) in `variables.tf`.

## Phase 2: Identity & Access Management (`identity.tf`)
1. **Keystone Roles:** Create `media_reader` and `media_uploader` roles.
2. **Keystone Users:** Create users `app_frontend_reader` and `app_frontend_uploader` with generated random passwords.
3. **SSH Keypair:** Generate an SSH keypair (`hotel-keypair`) using the `tls_private_key` and `openstack_compute_keypair_v2` resources.
4. **Local Key Storage:** Use `local_sensitive_file` to save the private key securely to `~/.ssh/hotel-key.pem` on the host.

## Phase 3: Network Infrastructure (`network.tf`)
1. **Private Network:** Create `hotel-private-net`.
2. **Subnet:** Create a subnet `10.0.1.0/24` inside `hotel-private-net` with DNS nameservers configured.
3. **Router:** Create `hotel-router` attached to the external provider network.
4. **Router Interface:** Attach the private subnet to `hotel-router` to ensure outbound internet access (essential for `cloud-init` package downloads).
5. **Floating IPs:** Allocate Floating IPs for the Load Balancer VIP and the Bastion host.

## Phase 4: Security Groups (`security.tf`)
Implement strict network segmentation:
1. **Bastion SG:** Ingress TCP/22 from `0.0.0.0/0`. Egress to anywhere.
2. **Frontend SG:** Ingress TCP/80 from `0.0.0.0/0` (or specifically the LB subnet) and TCP/22 explicitly from the Bastion SG.
3. **Backend SG:** Ingress TCP/80 and TCP/22 explicitly from the Frontend SG.
4. **Database SG:** Ingress TCP/5432 explicitly from the Backend SG, and TCP/22 from Bastion SG (for debugging if needed).

## Phase 5: Images & Flavors (`compute.tf`)
1. **Glance Image:** Use `openstack_images_image_v2` to download and register `jammy-server-cloudimg-amd64.img` (Ubuntu 22.04) from the official cloud-images URL.
2. **Cirros Image Data:** Use a data block to fetch the existing `cirros` image ID for the bastion.
3. **Custom Flavor:** Create the `hotel_flavor` (1 vCPU, 2048MB RAM, 10GB Disk).

## Phase 6: Cloud-Init Configurations
Create local template files to bootstrap the instances:
1. `cloud-init/frontend-init-node.yaml`: Update packages, install a web server (e.g., nginx/python http.server), and serve "Frontend node {i}".
2. `cloud-init/backend-init-node.yaml`: Update packages, install Python/FastAPI/Uvicorn, and run a simple REST API on port 80.
3. `cloud-init/cloud-init-db.yaml`: Install PostgreSQL, configure listening addresses, and create the application database and user.

## Phase 7: Compute Instances (`compute.tf`)
Provision the instances using the network, SGs, flavor, and images defined above:
1. **Bastion Node (1x):** Cirros image, Bastion SG, public Floating IP association.
2. **Database Node (1x):** Ubuntu image, DB SG, `cloud-init-db.yaml` user_data.
3. **Backend Node (1x):** Ubuntu image, Backend SG, `backend-init-node.yaml` user_data.
4. **Frontend Nodes (2x):** Ubuntu image, Frontend SG, `frontend-init-node.yaml` user_data (pass index `count.index` to the template).

## Phase 8: Load Balancing (`gateway.tf`)
Utilize Octavia via the OVN provider:
1. **Load Balancer:** Create `hotel-lb` on the private subnet. **CRITICAL:** Set `loadbalancer_provider = "ovn"`.
2. **Listener:** Create a TCP listener on port 80.
3. **Pool:** Create a pool with `lb_method = "SOURCE_IP_PORT"` and `protocol = "TCP"`.
4. **Members:** Add the 2 Frontend nodes to the pool (address = frontend private IPs, protocol_port = 80).
5. **Health Monitor:** Add a TCP health monitor (delay: 5s, timeout: 3s, max_retries: 3).
6. **FIP Association:** Associate the allocated Floating IP with the LB VIP port.

## Phase 9: Object Storage (`storage.tf`)
1. **Swift Container:** Create the `hotel-assets` container.
2. **Access Control (ACLs):** Configure read/write ACLs on the container mapped to the Keystone roles/users created in Phase 2.
3. **Asset Seeding:** Use `openstack_objectstorage_object_v1` to upload initial placeholder images (`.png`/`.jpg`) to the container.

## Phase 10: Outputs & Secrets (`outputs.tf`)
1. **Environment File Generation:** Use the `local_file` resource to generate an `.env` file on the local machine. This file will contain:
   - Database credentials
   - Keystone user credentials
   - Swift Endpoint URLs
   - Load Balancer Public IP
   - Bastion Public IP
2. Ensure no sensitive values are directly output to the CLI console (use `sensitive = true` on output blocks where applicable).
