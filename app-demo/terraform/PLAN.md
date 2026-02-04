# PLAN.md - AWS to OpenStack Migration Strategy

## 1. Goal
Migrate the infrastructure provisioning for `progettazione-hotel` from AWS (simulated via LocalStack) to a single-node OpenStack (DevStack) environment.

## 2. Analysis of Current AWS Architecture
The current setup relies heavily on AWS Managed Services:
*   **Compute:** EC2 (ASG + Launch Templates), ALB.
*   **Networking:** VPC, Public/Private Subnets, Route53, NAT Gateway.
*   **Storage:** S3 (Frontend Hosting + Media Storage), RDS (PostgreSQL).
*   **Identity:** Cognito (User Pools, Clients).
*   **Gateway:** API Gateway V2 (HTTP API, JWT Authorizer).
*   **Distribution:** CloudFront.

## 3. Migration Strategy: "Consolidated IaaS"
Since DevStack typically lacks direct equivalents for high-level managed services (Cognito, CloudFront, API Gateway V2), we will adopt a **Self-Hosted** strategy using standard Compute Instances (Nova).

We will consolidate services to fit the single-node constraint efficiently:

| AWS Resource | OpenStack Equivalent Strategy | Implementation Detail |
| :--- | :--- | :--- |
| **VPC / Subnets** | **Neutron Network** | 1 Private Network + 1 Router linked to Public Network. |
| **Security Groups** | **Security Groups** | `openstack_networking_secgroup_v2` rules. |
| **RDS (Postgres)** | **DB Node** | A dedicated Compute Instance with PostgreSQL installed via `cloud-init`. |
| **S3 (Media)** | **Swift** (Object Storage) | `openstack_object_storage_container_v1` (if enabled) or MinIO on DB Node. |
| **Cognito** | **Auth Service** | A simple mock Auth service or Keycloak running on a container. *Decision: Use Keycloak for compatibility.* |
| **API Gateway + ALB** | **Gateway Node (Nginx)** | A Compute Instance running Nginx as Reverse Proxy & Load Balancer. |
| **CloudFront + S3 Web**| **Gateway Node (Nginx)** | Nginx serving static files directly. |
| **EC2 Backend** | **App Nodes** | Compute Instances running the FastAPI application. |

## 4. Implementation Steps

### Phase 1: Provider & Networking
1.  **Configure Provider:** Set up `terraform-provider-openstack`.
2.  **Network Setup:**
    *   Create a private network (`hotel-net`) and subnet (`192.168.1.0/24`).
    *   Create a Router connecting `hotel-net` to the DevStack `public` network.
3.  **Security Groups:**
    *   `sg-web`: Allow 80/443 from Public.
    *   `sg-internal`: Allow all internal traffic (DB, App, Auth).
    *   `sg-ssh`: Allow 22 from Public (for debugging).

### Phase 2: Data & State (Stateful Layer)
1.  **Database Instance:**
    *   Launch `db-node` (Ubuntu/Debian).
    *   **User Data:** Install PostgreSQL, create User/DB, run `schema.sql`.
2.  **Object Storage:**
    *   Create Swift Container `hotel-media`.
    *   Script the upload of `seed_media` files to Swift.

### Phase 3: Application Layer (Stateless Layer)
1.  **Backend Instances:**
    *   Launch `app-node-1` (and optional `app-node-2`).
    *   **User Data:** Install Python, pip, clone repo (or sync files), run `uvicorn`.
2.  **Auth Service (Cognito Replacement):**
    *   Launch `auth-node` (or run on `db-node` to save resources).
    *   Run Keycloak (Docker) or a lightweight mock compatible with the Frontend's JWT expectations.

### Phase 4: Gateway & Ingress (The "Edge")
1.  **Gateway Instance:**
    *   Launch `gateway-node` with a **Floating IP**.
    *   **User Data:** Install Nginx.
    *   **Configuration:**
        *   `/api/` -> Proxy pass to `app-node` (Round Robin).
        *   `/` -> Serve Static Frontend Files (synced from local `app-demo/frontend/build`).

### Phase 5: Integration & Output
1.  **Generate Config:**
    *   Recreate the `local_file` "dotenv" resource.
    *   Map the new Floating IP and internal IPs to `localstack.env` (or `openstack.env`) for the app to consume.

## 5. Verification
*   **Net Check:** Can ping Gateway public IP?
*   **App Check:** Does the Frontend load?
*   **API Check:** Do `/api/search` calls return data from Postgres?
*   **Auth Check:** Can we login (via Keycloak/Mock)?
