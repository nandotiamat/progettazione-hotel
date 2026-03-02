# Plan: Translate AWS(LocalStack) Terraform to OpenStack(DevStack)

## Goal

Port the current AWS-oriented Terraform (built for LocalStack) into a functionally equivalent Terraform configuration that provisions on a constrained local DevStack OpenStack (`stable/2025.1`) deployment.

## Ground Rules / Constraints

- No Terraform code changes until this plan is approved.
- Target platform is DevStack inside a nested VM (MTU 1450); assume performance and networking quirks.
- Enabled OpenStack components (from `local.conf`): Neutron + OVN, Swift, Octavia (OVN provider). No Heat/Senlin/Aodh/Trove are mentioned as enabled.

## Step 1: Inventory What The AWS Stack Does

I will produce a service-by-service inventory of the existing `.tf` files, grouping by concerns:

- Networking: VPC, public/private subnets, route tables, IGW, Route53 private zone.
- Security: ALB SG, EC2 SG, DB SG, plus LocalStack debug rules.
- Compute: ALB + target group + listener, ASG + launch template, manual debug EC2.
- Storage: S3 buckets (frontend website + media), CloudFront distribution, seed objects.
- Database: RDS Postgres + subnet group + local-exec schema apply.
- Identity/API: Cognito user pool/client/domain/groups; API Gateway v2 HTTP API with JWT authorizer and routes.
- Local integration: `local_file` that writes `/config/localstack.env`.

Deliverable of this step: a short mapping table and a list of features that cannot be replicated 1:1 in the target DevStack.

## Step 2: Decide The OpenStack Equivalents (Mapping)

I will map each AWS capability to an OpenStack-native analogue (or document a workaround), prioritizing what DevStack actually has:

- VPC/Subnets/IGW/Routes -> Neutron network(s), subnets, router, router interface, external gateway.
- Security Groups -> Neutron security groups + rules.
- ALB -> Octavia load balancer (LB, listener, pool, members, health monitor).
- ASG/Launch Template/CloudWatch alarms -> likely not available (no autoscaling services enabled). Plan: emulate with a fixed-size instance group via `count` and document autoscaling as “out of scope” unless Senlin/Aodh are enabled.
- S3 buckets -> Swift containers.
- CloudFront -> no CDN equivalent by default. Plan: omit CDN, or provide an optional “cache proxy” VM in front of Swift if required.
- RDS -> Trove is not enabled. Plan: run Postgres on a Nova instance (optionally with a Cinder volume) and restrict access via security groups.
- Route53 private zone -> DevStack typically does not include Designate; plan: omit DNS zone and rely on IPs/outputs (or optional `/etc/hosts` notes).
- Cognito + API Gateway -> no direct equivalents in base DevStack. Plan: replace with:
  - Identity: out of scope (or optionally integrate with an external IdP) and remove JWT authorizer resources.
  - API Gateway: route traffic through Octavia LB directly to backend service(s).

Deliverable of this step: a clear “Supported / Workaround / Omitted” matrix.

## Step 3: Define The Target Terraform Structure

I will propose a clean OpenStack root module layout (keeping the repo’s file-by-domain pattern), for example:

- `provider.tf`: OpenStack provider config (auth URL, username/password, project, domain, region).
- `network.tf`: Neutron networks/subnets/router.
- `security.tf`: security groups and rules.
- `compute.tf`: instances (backend nodes, optional bastion/debug node), user-data/cloud-init.
- `lb.tf`: Octavia resources.
- `storage.tf`: Swift containers/objects (as supported).
- `db.tf`: Postgres instance + volume + initialization approach.
- `outputs.tf`: endpoints, IPs, container names, etc.
- `variables.tf`: all inputs with descriptions + validations.

Deliverable: a final file list and what each file will contain.

## Step 4: Inputs, Defaults, and Environment Assumptions

I will define what must be configurable to run on a local DevStack:

- OpenStack auth: `auth_url`, `region`, `user_name`, `password`, `project_name`, `user_domain_name`, `project_domain_name`.
- Image/flavor/keypair: `image_name` or `image_id`, `flavor_name`, `keypair_name`.
- External network: `external_network_name` (often `public`).
- Fixed IP ranges and MTU considerations.
- Instance count for “autoscaled” backend group.
- Ports: backend app (8000), HTTP (80), SSH (22), Postgres (5432).

Deliverable: variable list with proposed defaults that match typical DevStack installs.

## Step 5: Database Initialization Strategy (No Surprises)

The AWS module uses `null_resource` + `local-exec` + `psql` against a forwarded port.

For OpenStack, I will propose one of these (recommended first):

1. Cloud-init user-data on the DB VM to install Postgres and apply schema on first boot.
2. `remote-exec` provisioner via SSH to apply schema (requires reachable SSH and keypair).
3. Keep `local-exec` but only if the DB is reachable from the Terraform runner network.

Deliverable: selected approach, with the exact operational steps and required prerequisites.

## Step 6: Local Outputs / "dotenv" File Replacement

The current module writes `/config/localstack.env` containing many AWS-specific values.

For the OpenStack port, I will:

- Replace with a generated env file that exports OpenStack-derived endpoints (LB VIP, backend IPs, Swift container names/URLs, DB IP/port/user/pass).
- Keep the file generation via Terraform `local_file` (same pattern) but adjust variables.

Deliverable: list of env keys we will keep/rename/drop, and where consumers should read them.

## Step 7: Verification Plan

Once code is written (after your approval), I will verify with:

- `terraform fmt -recursive`
- `terraform init`
- `terraform validate`
- `terraform plan`

And basic functional checks (depending on what DevStack exposes):

- Confirm networks/subnets/router and connectivity.
- Confirm instances are ACTIVE and reachable (SSH if configured).
- Confirm Octavia LB is ACTIVE and routes to backend members.
- Confirm Swift containers exist and objects (if any) upload successfully.
- Confirm DB is reachable from backend security group and schema initialization succeeded.

## Step 8: Explicit Non-Goals (Unless You Want Them)

These AWS features are expected to be omitted or significantly simplified unless you explicitly request deeper OpenStack services:

- Cognito user pools/groups and JWT authorizer behavior.
- API Gateway routing features.
- CloudFront CDN.
- Route53 private DNS.
- True autoscaling with alarms/policies.
- Managed DB (Trove) if not enabled.

## Approval Checkpoint

If you approve this plan, I will proceed to implement the OpenStack Terraform configuration following the mapping and structure above.
