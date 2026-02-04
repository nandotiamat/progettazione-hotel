# Migration Description: AWS to OpenStack (DevStack)

## 1. Overview
This document describes the migration of the infrastructure provisioning code for `progettazione-hotel`. The original infrastructure was designed for AWS (simulated via LocalStack) using managed services. The new infrastructure targets a single-node OpenStack (DevStack) environment, requiring a shift to self-hosted components and standard IaaS resources.

## 2. Architecture Comparison ("What & Why")

The core challenge was translating high-level AWS managed services into standard OpenStack compute and network primitives suitable for a constraint-limited DevStack environment.

| Feature | AWS Implementation | OpenStack Implementation | Reason for Change |
| :--- | :--- | :--- | :--- |
| **Networking** | VPC, Public/Private Subnets, NAT Gateway | Neutron Network + Router | DevStack networking is simpler. We used a single private subnet connected to a public router to mimic the "Private + NAT" topology without the complexity of multiple subnets. |
| **Load Balancing** | Application Load Balancer (ALB) | Nginx on "Gateway Node" | Octavia (OpenStack LBaaS) is often unstable or missing in minimal DevStack installs. A dedicated Nginx instance provides robust Layer 7 routing and static file serving with less overhead. |
| **Database** | RDS (Managed PostgreSQL) | Compute Instance ("DB Node") | Trove (DBaaS) is rarely deployed in DevStack. A self-hosted PostgreSQL instance on a standard VM is reliable and sufficient for this scale. |
| **Object Storage** | S3 (Buckets + Policies) | Swift Containers | Swift is the direct equivalent of S3. We maintained the "Media" storage concept using a public read-only container. |
| **Identity/Auth** | Cognito (User Pools) | Keycloak (Docker container) | There is no direct OpenStack equivalent to Cognito for *application* users (Keystone is for infrastructure users). Keycloak is the industry standard for self-hosted IAM and supports the OIDC/JWT flow required by the frontend. |
| **API Gateway** | API Gateway V2 | Nginx Reverse Proxy | API Gateway is a complex serverless component. Nginx handles the path-based routing (`/api` vs `/`) effectively in a monolithic IaaS setup. |

## 3. Implementation Details ("How")

The migration was executed in 5 logical phases, each committed to the `gemini3pro` branch.

### Phase 1: Networking & Security
*   **File:** `network.tf`, `security.tf`
*   **Action:** Defined a private network (`hotel-net`) and a router to the external world. Created Security Groups to act as firewalls.
*   **Detail:** We created specific groups (`sg_web`, `sg_internal`, `sg_ssh`) to enforce the principle of least privilege, ensuring only the Gateway node is exposed to the public web.

### Phase 2: Stateful Layer (Data)
*   **Files:** `compute_db.tf`, `storage.tf`
*   **Action:** Provisioned the database and object storage.
*   **Detail:**
    *   **DB:** Used `user_data` (cloud-init) to install PostgreSQL and inject the `schema.sql` directly at boot time. This automates the "seed" process without needing external connectivity/provisioners.
    *   **Storage:** Created a Swift container and mapped the local `seed_media/` files to OpenStack objects using Terraform's `for_each` loop.

### Phase 3: Stateless Layer (App & Auth)
*   **Files:** `compute_app.tf`, `compute_auth.tf`
*   **Action:** Launched the application servers and the authentication service.
*   **Detail:**
    *   **App:** Created 2 instances for redundancy (simulating the AWS AutoScaling Group). The `user_data` script installs Python, creates a venv, and sets up a Systemd service for FastAPI.
    *   **Auth:** Launched a node running Keycloak via Docker. This allows us to replace Cognito with a containerized solution that speaks the same OIDC language.

### Phase 4: Gateway Layer (The "Edge")
*   **Files:** `compute_gateway.tf`, `nginx_setup.sh.tpl`
*   **Action:** Created the single entry point for the cluster.
*   **Detail:** This node requests a **Floating IP** (Public IP). It uses Nginx to route traffic:
    *   `/api/` -> Forwarded to the `app_nodes` (Round Robin load balancing).
    *   `/auth/` -> Forwarded to Keycloak.
    *   `/` -> Serves static Frontend files (assumed to be deployed to `/var/www/html`).

### Phase 5: Integration
*   **Files:** `outputs.tf`
*   **Action:** Generated configuration for the application.
*   **Detail:** Created a `local_file` resource that writes `openstack.env`. This file contains the IPs (Floating and Internal) and credentials needed by the application code to connect to the new infrastructure, effectively bridging the gap between Terraform and the Application logic.

## 4. Usage

To deploy this stack on your DevStack instance:

1.  **Source Creds:** `source ~/devstack/openrc admin admin`
2.  **Init:** `terraform init`
3.  **Plan:** `terraform plan`
4.  **Apply:** `terraform apply -auto-approve`

Once complete, the `openstack.env` file will contain the public URL to access your hotel application.
