# Migration Plan: AWS to OpenStack Terraform

This plan details the steps to translate the existing AWS LocalStack Terraform configuration into an OpenStack DevStack environment using the OVN and Swift components specified in the requirements.

## Step 1: Provider Configuration & Initialization
- Define the `terraform` block requiring the latest `terraform-provider-openstack`.
- Configure the OpenStack provider to use `clouds.yaml` for authentication (no hardcoded credentials).

## Step 2: IAM & Security (Keystone & Neutron)
- **Users & Roles:** Create Keystone users (`app_frontend_reader`, `app_frontend_uploader`) with generated passwords. Create roles (`media_reader`, `media_uploader`) and assign them.
- **SSH Keypair:** Generate a new SSH keypair (`hotel-keypair`) and use the `local_sensitive_file` resource to securely save the private key to `~/.ssh/hotel-key.pem`.
- **Security Groups (Strict Segmentation):**
  - **Bastion SG:** Ingress TCP/22 from `0.0.0.0/0`.
  - **Frontend SG:** Ingress TCP/80 from `0.0.0.0/0` (or LB subnet) and TCP/22 from Bastion SG.
  - **Backend SG:** Ingress TCP/80 and TCP/22 exclusively from Frontend SG.
  - **Database SG:** Ingress TCP/5432 exclusively from Backend SG.

## Step 3: Networking Topology (Neutron via OVN)
- Create a private network `hotel-private-net`.
- Create a subnet (`10.0.1.0/24`) attached to the network.
- Create a router `hotel-router` connected to the external provider network.
- Add a router interface to the private subnet to ensure outbound internet access (required for `cloud-init` package downloads).

## Step 4: Images & Flavors (Glance & Nova)
- **Flavor:** Create the `hotel_flavor` (1 vCPU, 2048MB RAM, 10GB Disk).
- **Images:** 
  - Define an `openstack_images_image_v2` resource to download and register the `jammy-server-cloudimg-amd64.img` (Ubuntu).
  - Use a data source to locate the existing `cirros` image for the Bastion node.

## Step 5: Cloud-Init Configurations
- Create local files or `template_file` data blocks for:
  - `frontend-init-node.yaml`: Configures HTTP server on port 80.
  - `backend-init-node.yaml`: Installs/runs FastAPI server on port 80.
  - `cloud-init-db.yaml`: Installs PostgreSQL, creates user/database.

## Step 6: Compute Instances (Nova)
- Provision 1x **Bastion Node**: Uses `cirros` image, Bastion SG.
- Provision 1x **Database Node**: Uses Ubuntu image, DB SG, and `cloud-init-db.yaml`.
- Provision 1x **Backend Node**: Uses Ubuntu image, Backend SG, and `backend-init-node.yaml`.
- Provision 2x **Frontend Nodes**: Uses Ubuntu image, Frontend SG, and `frontend-init-node.yaml`.

## Step 7: Load Balancing (Octavia via OVN)
- Provision an Octavia Load Balancer (`hotel-lb`) on the private subnet, strictly setting `loadbalancer_provider = "ovn"`.
- Create a TCP Listener on port 80.
- Create a Pool with the `SOURCE_IP_PORT` algorithm and TCP protocol.
- Add the 2 Frontend nodes as pool members (TCP/80).
- Attach a TCP Health Monitor (delay: 5s, timeout: 3s, retries: 3).
- Allocate a Floating IP and associate it with the Load Balancer VIP. Allocate a second Floating IP for the Bastion node.

## Step 8: Object Storage (Swift)
- Provision a Swift container named `hotel-assets`.
- Configure the container ACLs to grant access via the newly created Keystone roles (`media_reader`, `media_uploader`).
- Use the `openstack_objectstorage_object_v1` resource to automate the uploading of seed images (`.png`/`.jpg`).

## Step 9: Environment Secrets Management
- Use the `local_file` resource to generate an `.env` file locally.
- Populate it with database credentials, Keystone user credentials, the LB Floating IP, and Swift endpoint URLs so they are not hardcoded or exposed in standard outputs.

---

Please review this plan. If you approve, I will proceed with writing the Terraform configurations and corresponding cloud-init files.