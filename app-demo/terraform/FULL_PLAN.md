# Full Plan: Implement OpenStack Terraform Target (DevStack stable/2025.1)

This plan assumes DevStack is already installed and running with Neutron (OVN), Swift, and Octavia enabled, per `PROMPT.md`. The deliverable is a new Terraform configuration that provisions the OpenStack equivalent of the current AWS(LocalStack) stack, with explicit substitutes for AWS-only services.

## 0) Define Scope And Parity Targets

- Primary parity (must have):
  - Network segmentation similar to public/private subnets.
  - Security groups for: load balancer ingress, backend nodes, database.
  - HTTP load balancing to backend service on port 8000.
  - Object storage containers: frontend artifacts + media.
  - A Postgres database endpoint reachable from backend.
  - Clear outputs for consumers (frontend/backend env vars).

- Non-parity / substitutes (documented and accepted differences):
  - Cognito + API Gateway: replaced by direct LB-to-backend routing (no managed JWT authorizer).
  - CloudFront: omitted (no CDN in baseline DevStack).
  - Route53 private zone: omitted unless Designate is present.
  - ASG/CloudWatch alarms: replaced with a fixed instance count unless autoscaling services exist.
  - RDS: replaced by Postgres on a Nova instance unless Trove is available.

Deliverable: a short "parity contract" in `FULL_PLAN.md` plus a checklist to validate success.

## 1) Collect DevStack Runtime Inputs (No Code Yet)

On the DevStack node, confirm/record the following values (these become Terraform variables):

- OpenStack auth:
  - `OS_AUTH_URL`, `OS_USERNAME`, `OS_PASSWORD`, `OS_PROJECT_NAME`
  - `OS_USER_DOMAIN_NAME`, `OS_PROJECT_DOMAIN_NAME`
  - `OS_REGION_NAME` (if set)

- Network:
  - External network name (typically `public`).
  - External subnet CIDR and allocation pools.
  - DNS resolver(s) if required.

- Compute:
  - Image to use (e.g., Ubuntu cloud image name/ID).
  - Flavor to use (lightweight given nested virt).
  - Keypair name (or whether Terraform should create/import one).

- Swift:
  - Whether temp URLs are needed (usually not for baseline parity).

- Octavia:
  - Confirm LBaaS works with OVN provider in this deployment.

Deliverable: a variable list + expected defaults for a typical DevStack.

## 2) Create A New Terraform Root Layout

Create an OpenStack-focused structure, keeping the existing "by domain" organization:

- `provider.tf`: OpenStack provider config (all via variables).
- `variables.tf`: typed inputs, descriptions, validations, sensible defaults.
- `network.tf`: Neutron networks/subnets/router.
- `security.tf`: security groups and rules.
- `compute.tf`: backend instances (count-based), optional debug/bastion instance.
- `lb.tf`: Octavia load balancer, listener, pool, members, health monitor.
- `storage.tf`: Swift containers, optional object uploads for seed/media.
- `db.tf`: Postgres VM + optional volume + initialization.
- `outputs.tf`: VIPs, floating IPs, container names, DB endpoint, etc.
- `local_env.tf` (optional): `local_file` generation for consumers.

Deliverable: empty files with headings and placeholders (no resources yet until you decide to proceed), plus a consistent naming convention.

## 3) Map AWS Resources To OpenStack Resources (Implementation Order)

Implement in this order to reduce churn and make `terraform plan` useful early:

### Phase A: Provider + Data Sources

- Configure the OpenStack provider.
- Add data sources to discover:
  - external network ID
  - image ID
  - flavor ID

Acceptance criteria:
- `terraform init` succeeds.
- `terraform validate` succeeds.
- `terraform plan` shows only data reads.

### Phase B: Networking (Neutron)

Target topology:

- One tenant network for "private" workload.
- One subnet for the private network.
- One router with gateway set to the external network.
- Router interface attached to private subnet.

Optionally (if you want AWS-like separation):

- Add a second tenant network/subnet as "public" and route accordingly.
- In DevStack, a simpler model often works: private tenant network + floating IPs for ingress.

Acceptance criteria:
- Network/subnet/router become ACTIVE.
- Instances can obtain DHCP addresses on the tenant subnet.

### Phase C: Security Groups

Define security groups analogous to the AWS intent:

- `lb_sg`: allow inbound 80/443 from 0.0.0.0/0; allow outbound all.
- `backend_sg`: allow inbound 8000 from `lb_sg`; allow inbound 22 from a configurable admin CIDR; allow outbound all.
- `db_sg`: allow inbound 5432 from `backend_sg`; deny public access by omission.

Acceptance criteria:
- Rules exist and are attached to the correct ports.
- Backend cannot be reached directly on 8000 from the internet if only LB has a floating IP.

### Phase D: Compute (Backend + Optional Debug)

Backend group:

- Create N instances via `count` (replacement for ASG).
- Attach `backend_sg`.
- Use cloud-init to install and start a simple HTTP service on port 8000 (or your real backend if you provide an image).

Debug/bastion (optional):

- Create 1 instance with a floating IP, SSH access, and ability to curl the VIP and DB.

Acceptance criteria:
- Instances are ACTIVE.
- From debug/bastion, you can reach backend nodes and verify the app responds on 8000.

### Phase E: Load Balancing (Octavia)

Implement an Octavia LB with:

- Load balancer on the private subnet.
- Listener on port 80.
- Pool (HTTP) and members pointing at backend fixed IPs:8000.
- Health monitor (HTTP) with a tolerant path (e.g., `/`).
- Floating IP attached to the VIP port (external ingress).

Acceptance criteria:
- LB provisioning reaches ACTIVE.
- `curl http://<floating_ip>/` returns backend response.
- Scaling test: increasing/decreasing backend count updates pool membership cleanly.

### Phase F: Object Storage (Swift)

Replace S3 buckets with Swift containers:

- `frontend_container`: for static frontend assets.
- `media_container`: for user uploads / seeded media.

Optional seeding:

- Upload local seed objects only if the files exist in-repo; otherwise skip and document.

Acceptance criteria:
- Containers exist.
- Optional objects upload successfully.
- Outputs include container names and (if needed) public endpoints or temp URL guidance.

### Phase G: Database Substitute (Postgres on Nova)

Because Trove is not enabled in the provided DevStack config, implement:

- One DB instance running Postgres.
- Attach `db_sg`.
- Prefer a dedicated Cinder volume if available (optional).
- Initialize DB via cloud-init:
  - install postgres
  - set user/password/dbname
  - apply schema if a `schema.sql` is provided

If cloud-init is unreliable in nested environments, fall back to:

- `remote-exec` over SSH from bastion/admin host.

Acceptance criteria:
- Backend nodes can connect to Postgres on 5432.
- Schema initialization is idempotent (safe to rerun).

### Phase H: Outputs And Local Env File

Replace the AWS `local_file` dotenv with OpenStack outputs:

- `LB_PUBLIC_IP` (Octavia VIP floating IP)
- `BACKEND_PRIVATE_IPS` (list)
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASS`, `DB_NAME`
- `SWIFT_FRONTEND_CONTAINER`, `SWIFT_MEDIA_CONTAINER`
- Any OpenStack endpoints if consumers need them

Write a generated env file (path configurable) for other components to consume.

Acceptance criteria:
- Outputs are stable and human-friendly.
- Env file is created/updated on `apply`.

## 4) Handle Missing AWS-Only Features (Explicit Decisions)

For each AWS-only capability, implement one of: omit, stub, or replace.

- Cognito user pool/groups:
  - Omit. If authentication is needed, integrate at the application layer (not Terraform) or add an external IdP later.

- API Gateway JWT authorizer and routing:
  - Replace with LB routing only. If path-based routing is needed, use Octavia L7 policies (if supported) or run a reverse proxy (nginx/traefik) as the edge.

- CloudFront:
  - Omit. Optional future: deploy a caching proxy VM.

- Route53 private DNS:
  - Omit. Use Terraform outputs and/or cloud-init to write `/etc/hosts` inside instances if name stability matters.

- Autoscaling:
  - Fixed `count`. Optional future: add Senlin/Aodh if available.

- Managed RDS:
  - DB on VM. Optional future: Trove.

Deliverable: a "Differences" section in the README/notes explaining what changed and why.

## 5) Quality Gates (Run After Each Phase)

- `terraform fmt -recursive`
- `terraform validate`
- `terraform plan` (should be readable; avoid perpetual diffs)

After Phase E (LB):

- Confirm Octavia resources are ACTIVE.
- Verify connectivity from outside (host network) to LB floating IP.

After Phase G (DB):

- Verify DB port reachable only from backend security group.
- Run a simple query check (if you provide credentials and tooling path).

## 6) Performance/Reliability Considerations For Nested DevStack

- Keep flavors small; avoid creating many instances.
- Prefer a single tenant network and a single LB unless multi-network is required.
- Set health monitor intervals/timeouts conservatively to reduce flapping.
- Avoid heavy provisioning scripts; cloud-init should be minimal and idempotent.

## 7) Delivery Milestones

Milestone 1: Provider + network + security groups (plan/apply succeeds).

Milestone 2: Backend instances reachable + LB routes traffic from floating IP.

Milestone 3: Swift containers created + optional seeds handled.

Milestone 4: Postgres VM running + backend connectivity + schema initialization.

Milestone 5: Outputs + generated env file align with downstream consumers.

## 8) Final Acceptance Checklist

- `terraform init` / `validate` / `plan` succeed on the DevStack node.
- `terraform apply` provisions: network, router, SGs, backend instances, LB + FIP, Swift containers, DB VM.
- External client can reach the app via the LB floating IP.
- DB is not publicly reachable; backend can connect.
- All omitted AWS features are clearly documented with suggested future enhancements.
