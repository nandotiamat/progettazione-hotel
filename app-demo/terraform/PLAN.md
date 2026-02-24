# PLAN.md — AWS-to-OpenStack Terraform Migration

## Objective

Translate the existing AWS Terraform scripts (designed for LocalStack) into an equivalent
OpenStack Terraform configuration targeting a DevStack `stable/2025.1` environment.

---

## Available DevStack Services (from `local.conf`)

| Service         | Purpose                          | Available |
|-----------------|----------------------------------|-----------|
| Keystone        | Identity / Auth                  | Yes (default) |
| Nova            | Compute                         | Yes (default) |
| Neutron + OVN   | Networking                       | Yes (enabled) |
| Glance          | Image service                    | Yes (default) |
| Cinder          | Block storage                    | Yes (default) |
| Swift           | Object storage                   | Yes (enabled) |
| Octavia (OVN)   | Load balancing                   | Yes (enabled, OVN provider, no Amphora) |
| Horizon         | Dashboard                        | Yes (default) |
| Placement       | Resource tracking                | Yes (default) |
| **Trove**       | DBaaS (managed databases)        | **No** |
| **Cognito-equiv** | Identity federation            | **No native equivalent** |
| **API Gateway** | Managed API proxy                | **No native equivalent** |
| **CloudFront**  | CDN                              | **No native equivalent** |
| **IAM**         | Fine-grained access control      | **No equivalent** (Keystone roles only) |
| **CloudWatch**  | Monitoring/alarms                | **No equivalent** |
| **Route53**     | DNS                              | **No** (Designate not enabled) |
| **ACM**         | Certificates                     | **No** (Barbican not enabled) |

---

## AWS → OpenStack Service Mapping

| AWS Resource                     | OpenStack Equivalent                        | Notes |
|----------------------------------|---------------------------------------------|-------|
| `aws_vpc`                        | `openstack_networking_network_v2` + `openstack_networking_subnet_v2` | OVN-backed |
| `aws_subnet` (public/private)    | `openstack_networking_subnet_v2`            | Use router for external access |
| `aws_internet_gateway`           | `openstack_networking_router_v2` + gateway  | Connect to `public` external net |
| `aws_route_table`                | `openstack_networking_router_interface_v2`  | Router handles routing |
| `aws_security_group`             | `openstack_networking_secgroup_v2`          | Same concept |
| `aws_security_group_rule`        | `openstack_networking_secgroup_rule_v2`     | Same concept |
| `aws_lb` (ALB)                   | `openstack_lb_loadbalancer_v2` (Octavia)    | OVN provider, L4 only (no L7) |
| `aws_lb_target_group`            | `openstack_lb_pool_v2`                      | |
| `aws_lb_listener`                | `openstack_lb_listener_v2`                  | |
| `aws_launch_template` + `aws_autoscaling_group` | `openstack_compute_instance_v2` (multiple) | No native ASG; use `count`/`for_each` |
| `aws_instance`                   | `openstack_compute_instance_v2`             | |
| `aws_s3_bucket`                  | `openstack_objectstorage_container_v1`      | Swift containers |
| `aws_s3_object`                  | `openstack_objectstorage_object_v1`         | Swift objects |
| `aws_db_instance` (RDS)          | `openstack_compute_instance_v2` + provisioner | Self-managed PostgreSQL on a VM |
| `aws_cognito_*`                  | Keystone projects/users/roles (partial)     | No token-based auth pool equivalent |
| `aws_apigatewayv2_*`             | **No equivalent** — handled at app level    | |
| `aws_cloudfront_distribution`    | **No equivalent** — direct Swift/Nginx      | |
| `aws_iam_role` / `aws_iam_policy` | Keystone roles (simplified)               | |
| `aws_route53_zone`               | **Skipped** (no Designate)                  | |
| `aws_cloudwatch_metric_alarm`    | **Skipped** (no Ceilometer/Aodh)            | |

---

## Migration Steps

### Step 1: Provider & Skeleton (`main.tf`)

- Replace `hashicorp/aws` with `terraform-provider-openstack/openstack`
- Configure provider with DevStack credentials:
  - `auth_url = "http://192.168.1.13/identity"`
  - `user_name = "admin"`, `password = "secret"`
  - `tenant_name = "admin"` (or `demo`)
  - `region = "RegionOne"`
- Keep the `local_file.dotenv` pattern, updated with OpenStack output values

### Step 2: Networking (`network.tf`)

- Create `openstack_networking_network_v2.main` (internal network)
- Create two public subnets (`10.0.1.0/24`, `10.0.2.0/24`) and two private subnets (`10.0.3.0/24`, `10.0.4.0/24`) as `openstack_networking_subnet_v2`
- Create `openstack_networking_router_v2` connected to the DevStack `public` external network
- Attach public subnets to the router via `openstack_networking_router_interface_v2`
- Private subnets remain isolated (no router attachment — mirrors the AWS design with no NAT)
- Use `data.openstack_networking_network_v2` to reference the existing DevStack `public` network
- Outputs: network IDs, subnet IDs, router ID

### Step 3: Security Groups (`security.tf`)

- Create `openstack_networking_secgroup_v2` for:
  - **LB SG**: HTTP (80) and HTTPS (443) ingress from `0.0.0.0/0`
  - **Compute SG**: port 8000 from anywhere, port 80 from LB SG, SSH (22) from internal CIDR
  - **DB SG**: port 5432 from Compute SG only
- All groups get full egress (OpenStack allows by default, but we'll be explicit)
- Outputs: security group IDs

### Step 4: Compute — Load Balancer (`compute.tf`, part 1)

- Create `openstack_lb_loadbalancer_v2` on a public subnet
- Create `openstack_lb_listener_v2` on port 80 (HTTP)
- Create `openstack_lb_pool_v2` with ROUND_ROBIN, HTTP health check
- Create `openstack_lb_monitor_v2` for health checking (relaxed thresholds for DevStack)
- Note: Octavia with OVN provider is L4 only — no path-based routing. This is acceptable since the AWS config only uses a simple forward-all listener.

### Step 5: Compute — Instances (`compute.tf`, part 2)

- Replace ASG + Launch Template with 2x `openstack_compute_instance_v2` using `count` (simulating desired capacity of 2)
- Each instance attached to a private subnet, with the compute security group
- Use `user_data` script (same as the launch template)
- Reference a DevStack image (e.g., `cirros`) and flavor (e.g., `m1.small`) via data sources
- Register instances as `openstack_lb_member_v2` in the Octavia pool
- Create a debug instance equivalent in the default network
- Skip: CloudWatch alarm + auto-scaling policy (no Ceilometer/Aodh/Heat available)
- Outputs: LB VIP address (replaces ALB DNS name)

### Step 6: Object Storage (`storage.tf`)

- Create `openstack_objectstorage_container_v1` for:
  - **Frontend bucket** (`my-app-frontend-container`) — with read ACL for public access (`.r:*,.rlistings`)
  - **Media bucket** (`my-app-media-assets`) — private
- Seed media files with `openstack_objectstorage_object_v1` using `for_each` (same pattern as AWS)
- Skip: S3 bucket website configuration (Swift doesn't have native static website hosting in a basic DevStack setup — this will be documented)
- Skip: S3 bucket policy (use container ACLs instead)
- Outputs: container names, Swift endpoint URLs

### Step 7: Database (`storage.tf`, part 2)

- Since Trove is not available, deploy PostgreSQL as a `openstack_compute_instance_v2`:
  - Small flavor, attached to a private subnet, DB security group
  - `user_data` script that installs PostgreSQL, creates the database, user, and loads the schema
- Alternatively: use a `null_resource` with `local-exec` to run PostgreSQL in a container or directly on the DevStack host (simpler, closer to the LocalStack approach)
- Decision: Use a dedicated VM with `user_data` for a closer architectural match to RDS
- Outputs: DB instance IP, DB name

### Step 8: Identity (`identity.tf`)

- Use Keystone resources as a partial replacement for Cognito:
  - `openstack_identity_project_v3` — create an application project
  - `openstack_identity_user_v3` — create application users (if needed for seeding)
  - `openstack_identity_role_v3` — create an `OWNERS` role (maps to Cognito group)
  - `openstack_identity_role_assignment_v3` — assign roles
- Note: Keystone is NOT a drop-in replacement for Cognito. There is no user pool with self-registration, password policies, or JWT token issuance for frontend apps. This section provides a structural mapping only. The application backend would need to be modified to use Keystone tokens instead of Cognito JWTs.
- Outputs: project ID, auth URL

### Step 9: Skip — API Gateway (`gateway.tf`)

- OpenStack has **no equivalent** to API Gateway.
- The API Gateway functionality (JWT validation, routing, header injection, CORS) must be handled by the application backend itself or a reverse proxy (e.g., Nginx on a VM).
- Document this gap. No Terraform resources to create.

### Step 10: Skip — CloudFront (`frontend_distribution.tf`)

- OpenStack has **no CDN service**.
- Frontend static files are served directly from Swift (with public read ACL) or via Nginx on a VM.
- Document this gap. No Terraform resources to create.

### Step 11: IAM (`iam.tf`)

- Map to Keystone roles:
  - Create a custom role for the "backend service" concept
  - Assign the role to the project used by compute instances
- Note: OpenStack doesn't have instance profiles or fine-grained IAM policies. Application-level access to Swift would use Keystone credentials (username/password or application credentials) rather than instance-attached roles.
- Outputs: role ID

### Step 12: Dotenv File Generation (`main.tf`)

- Update `local_file.dotenv` to output OpenStack-specific values:
  - Keystone auth URL (replaces Cognito)
  - Swift endpoint + container names (replaces S3)
  - Database VM IP + credentials (replaces RDS endpoint)
  - Load balancer VIP (replaces ALB DNS)
  - Remove CloudFront, API Gateway, Cognito-specific values
  - Add OpenStack-specific values (project ID, region, etc.)

### Step 13: Variables (`variables.tf`)

- Update variables:
  - Replace `aws_region` with `os_region` (default: `"RegionOne"`)
  - Keep `db_password` (default: `"test"`)
  - Add `os_auth_url` (default: `"http://192.168.1.13/identity"`)
  - Add `os_user_name`, `os_password`, `os_tenant_name` with DevStack defaults
  - Add `image_name` (default: `"cirros-0.6.3-x86_64-disk"` or appropriate DevStack image)
  - Add `flavor_name` (default: `"m1.small"`)

---

## Gaps & Limitations Summary

| Feature               | Status      | Mitigation |
|-----------------------|-------------|------------|
| Auto Scaling (ASG)    | Not available | Fixed instance count with `count` |
| CloudWatch Alarms     | Not available | Skipped entirely |
| Cognito (User Pool)   | Partial only | Keystone project/roles; app changes needed |
| API Gateway           | Not available | App-level routing/auth; or Nginx reverse proxy |
| CloudFront (CDN)      | Not available | Direct Swift access or Nginx |
| RDS (Managed DB)      | Not available | Self-managed PostgreSQL on VM |
| Route53 (DNS)         | Not available | Skipped (no Designate) |
| IAM Instance Profiles | Not available | Keystone application credentials |
| S3 Static Website     | Partial      | Swift public container; no index.html routing |

---

## File Mapping (output files)

| New File                      | Replaces                    |
|-------------------------------|----------------------------|
| `main.tf`                     | `main.tf` (provider + dotenv) |
| `variables.tf`                | `variables.tf`             |
| `network.tf`                  | `network.tf`               |
| `compute.tf`                  | `compute.tf`               |
| `storage.tf`                  | `storage.tf`               |
| `security.tf`                 | `security.tf`              |
| `identity.tf`                 | `identity.tf` + `iam.tf`   |
| ~~`gateway.tf`~~              | Skipped (no equivalent)    |
| ~~`frontend_distribution.tf`~~ | Skipped (no equivalent)   |
| ~~`iam.tf`~~                  | Merged into `identity.tf`  |

---

## Order of Implementation

1. `variables.tf` — foundation, needed by everything
2. `main.tf` — provider configuration
3. `network.tf` — networking (all other resources depend on it)
4. `security.tf` — security groups (needed by compute/db)
5. `storage.tf` — Swift containers + DB VM
6. `compute.tf` — LB + compute instances
7. `identity.tf` — Keystone resources (IAM + partial Cognito mapping)
8. `main.tf` (dotenv) — final pass to wire all outputs together
