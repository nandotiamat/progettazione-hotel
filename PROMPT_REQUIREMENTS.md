# Role

You are a Senior DevOps Engineer.

# Objective

Your goal is to translate the provided AWS Terraform scripts into an equivalent OpenStack Terraform configuration.

# Context & Source Environment

The original AWS Terraform scripts were designed, tested, and deployed on a local LocalStack installation. These scripts are the ones you read initially while visiting this repository. Authentication to the OpenStack environment will be handled seamlessly via `clouds.yaml`.

**# Target Environment Constraints**
The target OpenStack environment is heavily constrained. It runs in a nested virtualized environment with the following architecture and specifications:

- **Host:** Windows
- **Guest VM:** Linux (75GB Storage, 6 vCPU, 32GB RAM)
- **OpenStack Deployment:** DevStack installed locally inside the Linux Guest VM.

**# DevStack Configuration**
The DevStack environment is based on the `stable/2025.1` branch ([https://opendev.org/openstack/devstack/src/branch/stable/2025.1/](https://opendev.org/openstack/devstack/src/branch/stable/2025.1/)).
It is deployed using the following `local.conf` configuration file. Pay close attention to the enabled components when writing the terraform code.

```bash
[[local|localrc]]

ADMIN_PASSWORD=secret
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

# Host IP
HOST_IP=192.168.1.13

# Logging
LOGFILE=$DEST/logs/stack.sh.log
LOGDAYS=2
LOG_COLOR=False

# --- ASSICURAZIONE SULLA VITA ---
disable_service o-hm o-hk
disable_service etcd3

# Swift
SWIFT_HASH=66a3d6b56c1f479c8b4e70ab5c2000f5
SWIFT_REPLICAS=1
SWIFT_DATA_DIR=$DEST/data

# MTU (nested virtualization)
PUBLIC_BRIDGE_MTU=1450
GLOBAL_PHYSNET_MTU=1450

# =========================
# 🔧 REQUIRED FIX (OVN)
# =========================

# Neutron + OVN
enable_service neutron
enable_service ovn-northd
enable_service ovn-controller
enable_service ovn-metadata-agent

# =========================
# 📦 ENABLE SWIFT
# =========================
enable_service s-proxy s-object s-container s-account

# Optional: If you want the Swift UI in Horizon (Dashboard)
enable_service swift-dashboard

# =========================
# 📦 ENABLE OCTAVIA
# =========================

enable_plugin neutron https://opendev.org/openstack/neutron stable/2025.1
enable_plugin octavia https://opendev.org/openstack/octavia stable/2025.1
enable_plugin octavia-dashboard https://opendev.org/openstack/octavia-dashboard stable/2025.1
enable_plugin ovn-octavia-provider https://opendev.org/openstack/ovn-octavia-provider stable/2025.1

enable_service octavia o-api o-cw o-da
OCTAVIA_USE_AMPHORA_PROVIDER=False
OCTAVIA_CONTROLLER_WORKER_NETWORK_DRIVER=noop_driver

```

# Target Architecture & Software Requirements

First, the target Terraform code must use the latest possible version of both terraform and the openstack provider. It also must fulfill the following architectural requirements, reflecting a 3-tier application setup:

**0. Glance**

Since the Compute Instances will need an ubuntu cloudimg, create a resource that adds the image `jammy-server-cloudimg-amd64.img` to Glance (use `image_source_url` field).

**1. Compute (Nova)**

- **Custom Flavor:** Provision a custom flavor (`hotel_flavor`) with minimal specs suitable for the nested environment (1 vCPU, 2048MB RAM, 10GB Disk).
- **Instances:** All instances (except for the bastion node) will use the Ubuntu `jammy-server-cloudimg-amd64.img`, allowing them to utilize `cloud-init` configuration files.
  - 2x Frontend nodes (configured via a `frontend-init-node.yaml`).
  - 1x Backend node (configured via `backend-init-node.yaml`).
  - 1x Database node (configured via `cloud-init-db.yaml`).
  - 1x Bastion node which will run the available `cirros` image.
- **Cloud-config files:**
  - `frontend-init-node.yaml`: It must serve a simple HTTP page on port 80 that says `Frontend node {i}` where `i` is the index of the frontend node.
  - `backend-init-node.yaml`: It must download all the packages needed in order to run a simple FastAPI server and then run it on port 80.
  - `cloud-init-db.yaml:` It must download all the packages needed to run a PostgreSQL database. It must also handle the DB initialization with the user creation, database creation...

- **Access:** All instances must be accessible via a generated SSH key pair (`hotel-keypair`). The private key will be stored in `~/.ssh/hotel-key.pem` on the host machine. The bastion node will be used to SSH into the internal instances from the outside.

**2. Networking & Security (Neutron & OVN)**

It is important to be consistent with the security groups rules and router interfaces to guarantee internet access (egress, to download packages from the internet) to all the VMs.

- **Topology:** A single private network (`hotel-private-net`) with a subnet (`10.0.1.0/24`) attached to an external/public router (`hotel-router`). All compute instances must belong to that private network.
- **Floating IPs:** Assign public IPs only to the Load Balancer VIP and the Bastion Host.
- **Security Groups (Strict Segmentation):**
- **Bastion SG**: Allow ingress TCP/22 from `0.0.0.0/0`.
- **Frontend SG:** Allow ingress TCP/80 (basically HTTP traffic) and TCP/22 from the Bastion SG.
- **Backend SG:** Allow ingress TCP/80 (basically HTTP traffic, it will run a RESTful API) and TCP/22 _strictly_ from the Frontend SG.
- **Database SG:** Allow ingress PostgreSQL TCP/5432 _strictly_ from the Backend SG.

**3. Load Balancing (Octavia via OVN)**

Since we are using OVN as a provider, everything must be handled at the TCP level.

- **Layer 4 LB:** Provision an Octavia Load Balancer (`hotel-lb`) using the `ovn` provider to offload traffic at the switch level. The `loadbalancer_provider = "ovn"` field MUST be used.
- **Routing:** Listen on TCP port 80 and forward to the Frontend pool members on TCP port 80.
- **Algorithm & Health:** Utilize the `SOURCE_IP_PORT` load balancing method with a TCP health monitor (5s delay, 3s timeout, 3 max retries).

**4. Storage & Identity (Swift & Keystone)**

- **Object Storage:** Provision a Swift container (`hotel-assets`) to host seed media files.
- **IAM & ACLs:** Implement granular access control by creating dedicated roles (`media_reader`, `media_uploader`) and binding them to specific Keystone users (`app_frontend_reader`, `app_frontend_uploader`). Apply these roles directly to the container's read/write ACLs.
- **Users**: The previously mentioned users must be created by the terraform script, as resources.
- **Secrets**: Secrets must not be hardcoded in the source code or exposed in the outputs. Instead, utilize the `local_file` resource to generate a .env file that holds all necessary secrets and environment variables.
- **Seeding:** Automate the upload of initial application assets (.png/.jpg files) into the Swift container during provisioning.
