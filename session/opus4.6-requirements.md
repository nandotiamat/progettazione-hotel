# Plan for translating AWS Terraform to OpenStack with DevStack constraints

**Session ID:** ses_3551169b7ffe7w7uNxvXnh4dOk
**Created:** 3/1/2026, 8:44:48 PM
**Updated:** 3/1/2026, 8:49:02 PM

---

## User

Read @PROMPT_REQUIREMENTS.md and create a @PLAN.md describing the steps you will take to solve the problem. Do not write any Terraform code until I approve the plan.

---

## Assistant (Build · claude-opus-4.6 · 167.1s)



Now let me explore the existing AWS Terraform files to understand the current infrastructure that needs to be translated.

**Tool: task**

**Input:**
```json
{
  "description": "Explore existing Terraform codebase",
  "prompt": "Explore the Terraform codebase at /Users/nando/Dev/hotel/app-demo/terraform thoroughly. I need to understand:\n\n1. List all .tf files and their purposes\n2. For each .tf file, summarize the key resources defined\n3. Check for any non-Terraform files referenced (SQL, seed images, cloud-init templates, etc.) in the ../terraform_content/ directory\n4. Identify the key outputs, variables, and locals used\n5. Check for any .env file generation patterns\n6. Look at the SSH key pair setup if any\n7. Check how S3 seeding is done (media files upload)\n\nReturn a comprehensive summary of the entire infrastructure, organized by file. Include resource names and types for each file.",
  "subagent_type": "explore"
}
```

**Output:**
```
task_id: ses_355114785ffe1FD6lx1rXo31Mu (for resuming to continue this task if needed)

<task_result>
The AGENTS.md mentions that these files live in `../terraform_content/` but the Terraform code references them via `${path.module}/schema.sql` and `${path.module}/seed_media/...`. There is a discrepancy -- the content files are located at `../terraform_content/` on the host, but the HCL expects them at the terraform module root. This suggests that at container runtime, the files are somehow made available (perhaps through an additional volume mount, a symlink, or a copy step that is not visible in the current docker-compose.yml).

Here is the comprehensive summary:

---

# Comprehensive Terraform Infrastructure Summary

## Overview

This is a flat root-module Terraform codebase for a full-stack hotel application, targeting **LocalStack** (local AWS emulation). There are **10 `.tf` files**, **no submodules**, and all infrastructure is applied automatically when `docker compose up` runs via the LocalStack Terraform Init Hook. Comments are written in **Italian** throughout.

---

## 1. File-by-File Breakdown

### `/Users/nando/Dev/hotel/app-demo/terraform/main.tf`
**Purpose:** Terraform/provider configuration and `.env` file generation.

| Resource/Block | Type | Name/Identifier | Description |
|---|---|---|---|
| `terraform {}` | Config | -- | Requires `hashicorp/aws ~> 5.0` |
| `provider "aws"` | Provider | -- | Region `us-east-1`, all endpoints at `http://localhost:4566`, credentials `test/test` |
| `local_file.dotenv` | `local_file` | `/config/localstack.env` | Generates a `.env` file with all infrastructure outputs |

**Key pattern -- `.env` generation:** The `local_file.dotenv` resource writes a comprehensive dotenv file to `/config/localstack.env` (a Docker named volume shared with backend and frontend containers). This file contains:
- Cognito config (pool ID, client ID, issuer URL, endpoint)
- API Gateway endpoint
- ALB DNS name
- S3 bucket names and endpoints (frontend + media)
- RDS connection details (endpoint, host, port, user, password, DB name)
- CloudFront domain name and ID

---

### `/Users/nando/Dev/hotel/app-demo/terraform/variables.tf`
**Purpose:** Centralized input variable declarations.

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | `string` | `"us-east-1"` | AWS region |
| `db_password` | `string` | `"test"` | Database password (default needed for LocalStack auto-apply) |

Only 2 variables. Both have defaults, which is required by the LocalStack init hook since no `.tfvars` file is passed.

---

### `/Users/nando/Dev/hotel/app-demo/terraform/network.tf`
**Purpose:** VPC, subnets, internet gateway, route tables, Route53, and data sources for LocalStack default VPC.

| Resource/Data | Type | Identifier | Description |
|---|---|---|---|
| `aws_vpc.main` | `aws_vpc` | `main` | VPC with CIDR `10.0.0.0/16`, DNS support enabled |
| `data.aws_availability_zones.available` | Data | `available` | Fetches available AZs |
| `aws_subnet.public_1` | `aws_subnet` | `public_1` | Public subnet `10.0.1.0/24` in AZ[0] |
| `aws_subnet.public_2` | `aws_subnet` | `public_2` | Public subnet `10.0.2.0/24` in AZ[1] |
| `aws_subnet.private_1` | `aws_subnet` | `private_1` | Private subnet `10.0.3.0/24` in AZ[0] |
| `aws_subnet.private_2` | `aws_subnet` | `private_2` | Private subnet `10.0.4.0/24` in AZ[1] |
| `aws_internet_gateway.gw` | `aws_internet_gateway` | `gw` | Internet Gateway attached to VPC |
| `aws_route_table.public` | `aws_route_table` | `public` | Public route table with `0.0.0.0/0` -> IGW |
| `aws_route_table_association.public_1` | `aws_route_table_association` | `public_1` | Associates public subnet 1 |
| `aws_route_table_association.public_2` | `aws_route_table_association` | `public_2` | Associates public subnet 2 |
| `aws_route_table.private` | `aws_route_table` | `private` | Private route table (no NAT, no internet) |
| `aws_route_table_association.private_1` | `aws_route_table_association` | `private_1` | Associates private subnet 1 |
| `aws_route_table_association.private_2` | `aws_route_table_association` | `private_2` | Associates private subnet 2 |
| `aws_route53_zone.private` | `aws_route53_zone` | `private` | Private DNS zone `myapp.local` |
| `data.aws_vpc.localstack_default` | Data | `localstack_default` | LocalStack default VPC (for debug EC2) |
| `data.aws_subnets.localstack_default` | Data | `localstack_default` | Subnets of default VPC |
| `data.aws_security_group.localstack_default_sg` | Data | `localstack_default_sg` | Default SG of default VPC |

**Outputs (4):**
- `vpc_id` -- VPC ID
- `public_subnet_ids` -- List of public subnet IDs
- `private_subnet_ids` -- List of private subnet IDs
- `private_dns_zone_id` -- Route53 zone ID

**Commented-out resources:** NAT Gateway (EIP, NAT GW, private route), public Route53 zone with ACM cert and DNS records for `hotelapp.com` (production pattern).

---

### `/Users/nando/Dev/hotel/app-demo/terraform/compute.tf`
**Purpose:** ALB, ASG, launch template, CloudWatch alarm, autoscaling policy, and a debug EC2 instance.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_lb.app_alb` | `aws_lb` | `app_alb` | Application Load Balancer `"myapp-load-balancer"`, public-facing, in public subnets |
| `aws_lb_target_group.app_tg` | `aws_lb_target_group` | `app_tg` | Target group `"myapp-target-group"`, port 80, relaxed health check (200-499) |
| `aws_lb_listener.front_end` | `aws_lb_listener` | `front_end` | HTTP listener on port 80, forwards to target group |
| `aws_launch_template.app_lt` | `aws_launch_template` | `app_lt` | Launch template with AMI `ami-df5de72bdb3b` (Ubuntu 22.04 LocalStack), `t2.micro` |
| `aws_autoscaling_group.app_asg` | `aws_autoscaling_group` | `app_asg` | ASG `"myapp-asg"`, desired=2, min=1, max=3, in private subnets, EC2 health check |
| `aws_cloudwatch_metric_alarm.cpu_high` | `aws_cloudwatch_metric_alarm` | `cpu_high` | Alarm on CPU > 70% for 2 periods |
| `aws_autoscaling_policy.scale_up` | `aws_autoscaling_policy` | `scale_up` | Scale up by 1 instance, 300s cooldown |
| `aws_instance.manual_debug_node` | `aws_instance` | `manual_debug_node` | Debug EC2 `m5.large` in default VPC, runs `python3 -m http.server 8000` via user_data |

**Outputs (1):**
- `alb_dns_name` -- ALB DNS name

**Notable:** The debug EC2 instance uses `user_data` with a heredoc `<<-EOF` to start a simple Python HTTP server. It is placed in the LocalStack default VPC (not the custom VPC) for better LocalStack compatibility.

---

### `/Users/nando/Dev/hotel/app-demo/terraform/storage.tf`
**Purpose:** S3 buckets (frontend + media), RDS PostgreSQL, DB schema seeding, and media file seeding.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_s3_bucket.frontend_bucket` | `aws_s3_bucket` | `frontend_bucket` | `"my-app-frontend-bucket-local"`, force_destroy=true |
| `aws_s3_bucket_website_configuration.frontend_config` | `aws_s3_bucket_website_configuration` | `frontend_config` | Static website hosting, index.html for both index and error (SPA) |
| `aws_s3_bucket_policy.frontend_public_policy` | `aws_s3_bucket_policy` | `frontend_public_policy` | Public read access (`s3:GetObject` for `*`) |
| `aws_s3_bucket.media_bucket` | `aws_s3_bucket` | `media_bucket` | `"my-app-media-assets-local"`, force_destroy=true, private |
| `aws_db_subnet_group.db_subnet_group` | `aws_db_subnet_group` | `db_subnet_group` | `"main-db-subnet-group"` in private subnets |
| `aws_db_instance.postgres` | `aws_db_instance` | `postgres` | PostgreSQL 13, `db.t3.micro`, 20GB, DB `"myappdb"`, user `"dbadmin"`, not public |
| `null_resource.db_setup` | `null_resource` | `db_setup` | Runs `psql` to seed DB schema via `local-exec` provisioner |
| `aws_s3_object.media_seed` | `aws_s3_object` | `media_seed` | Uploads 17 seed images via `for_each` on `local.media_files` |

**Locals (1):**
- `media_files` -- A map of 17 entries mapping S3 keys (e.g., `"prop01/front.png"`) to local file paths (e.g., `"${path.module}/seed_media/prop01_front.png"`)

**Outputs (6):**
- `s3_frontend_endpoint` -- S3 website hosting URL
- `s3_frontend_bucket_name` -- Frontend bucket name
- `s3_media_bucket_name` -- Media bucket name
- `s3_media_bucket_url` -- Media bucket base URL (`http://localstack:4566/{bucket}`)
- `rds_endpoint` -- RDS connection endpoint
- `rds_db_name` -- Database name

---

### `/Users/nando/Dev/hotel/app-demo/terraform/security.tf`
**Purpose:** Security groups for ALB, EC2, and RDS + debug rules for LocalStack default SG.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_security_group.alb_sg` | `aws_security_group` | `alb_sg` | `"alb-security-group"` -- HTTP/HTTPS from anywhere, all egress |
| `aws_security_group.ec2_sg` | `aws_security_group` | `ec2_sg` | `"ec2-security-group"` -- Port 8000 from anywhere (debug), port 80 from ALB SG only, SSH from VPC |
| `aws_security_group.db_sg` | `aws_security_group` | `db_sg` | `"rds-security-group"` -- Port 5432 from EC2 SG only |
| `aws_security_group_rule.debug_ingress_8000` | `aws_security_group_rule` | `debug_ingress_8000` | Opens port 8000 on LocalStack default SG |
| `aws_security_group_rule.debug_ingress_ssh` | `aws_security_group_rule` | `debug_ingress_ssh` | Opens port 22 on LocalStack default SG |

**Outputs (3):**
- `security_group_alb_id`
- `security_group_ec2_id`
- `security_group_db_id`

**Architecture:** Three-tier security model: Public (ALB) -> Application (EC2) -> Data (RDS). Each tier only accepts traffic from the tier above.

---

### `/Users/nando/Dev/hotel/app-demo/terraform/iam.tf`
**Purpose:** IAM role, policy, and instance profile for EC2 backend instances to access S3.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_iam_role.backend_role` | `aws_iam_role` | `backend_role` | `"hotel_backend_role"` -- assumable by EC2 service |
| `aws_iam_policy.s3_backend_policy` | `aws_iam_policy` | `s3_backend_policy` | `"hotel_s3_access_policy"` -- PutObject, GetObject, ListBucket, DeleteObject on media bucket |
| `aws_iam_role_policy_attachment.attach_s3_to_role` | `aws_iam_role_policy_attachment` | `attach_s3_to_role` | Attaches S3 policy to backend role |
| `aws_iam_instance_profile.backend_profile` | `aws_iam_instance_profile` | `backend_profile` | `"hotel_backend_profile"` -- wrapper for EC2 to use the role |

**Outputs:** None.

**Note:** IAM policies use `jsonencode()` inline (no `aws_iam_policy_document` data sources). The instance profile is defined but not currently attached to the launch template or debug EC2 instance.

---

### `/Users/nando/Dev/hotel/app-demo/terraform/identity.tf`
**Purpose:** Cognito User Pool, client, groups, and domain for authentication.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_cognito_user_pool.main_pool` | `aws_cognito_user_pool` | `main_pool` | `"myapp-user-pool"` -- password policy (8 chars, upper/lower/numbers), auto-verify email |
| `aws_cognito_user_group.owners` | `aws_cognito_user_group` | `owners` | `"OWNERS"` group, precedence 1 |
| `aws_cognito_user_pool_client.web_client` | `aws_cognito_user_pool_client` | `web_client` | `"myapp-web-client"` -- no secret (SPA), SRP + password + refresh auth flows, 60min access/id tokens, 1 day refresh token |
| `aws_cognito_user_pool_domain.main_domain` | `aws_cognito_user_pool_domain` | `main_domain` | Domain `"myapp-auth-domain-local"` |

**Outputs (3):**
- `cognito_user_pool_id`
- `cognito_client_id`
- `cognito_issuer_url`

---

### `/Users/nando/Dev/hotel/app-demo/terraform/gateway.tf`
**Purpose:** API Gateway v2 (HTTP) with JWT authorizer, backend integration, and routes.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_apigatewayv2_api.main_api` | `aws_apigatewayv2_api` | `main_api` | `"myapp-http-api"`, HTTP protocol, CORS for `localhost:5173` |
| `aws_apigatewayv2_authorizer.jwt_auth` | `aws_apigatewayv2_authorizer` | `jwt_auth` | `"cognito-authorizer"` -- JWT type, uses Cognito issuer |
| `aws_apigatewayv2_integration.backend_integration` | `aws_apigatewayv2_integration` | `backend_integration` | HTTP_PROXY to `http://backend:8000`, passes user claims via headers (`x-user-cognito-sub`, `x-user-email`, `x-user-role`) |
| `aws_apigatewayv2_route.options_route` | `aws_apigatewayv2_route` | `options_route` | `OPTIONS /{proxy+}` -- no auth (CORS preflight) |
| `aws_apigatewayv2_route.public_search_no_slash` | `aws_apigatewayv2_route` | `public_search_no_slash` | `GET /api/search` -- no auth (public) |
| `aws_apigatewayv2_route.public_search_subpaths` | `aws_apigatewayv2_route` | `public_search_subpaths` | `GET /api/search/{proxy+}` -- no auth (public) |
| `aws_apigatewayv2_route.default_route` | `aws_apigatewayv2_route` | `default_route` | `ANY /{proxy+}` -- JWT auth required (catch-all) |
| `aws_apigatewayv2_stage.default_stage` | `aws_apigatewayv2_stage` | `default_stage` | `$default` stage, auto_deploy=true |

**Outputs (1):**
- `api_gateway_endpoint`

**Route authorization model:** Public search endpoints (`/api/search`), CORS preflight (`OPTIONS`), everything else requires JWT.

**Commented-out resources:** VPC Link integration for production ALB connection (currently bypassed with direct `backend:8000` Docker DNS).

---

### `/Users/nando/Dev/hotel/app-demo/terraform/frontend_distribution.tf`
**Purpose:** CloudFront CDN distribution for the frontend S3 bucket.

| Resource | Type | Identifier | Description |
|---|---|---|---|
| `aws_cloudfront_distribution.s3_distribution` | `aws_cloudfront_distribution` | `s3_distribution` | Origin: S3 frontend bucket (regional domain), default root `index.html`, SPA error handling (403/404 -> index.html), redirect-to-https, default CloudFront cert |

**Outputs (2):**
- `cloudfront_domain_name`
- `cloudfront_id`

---

## 2. Non-Terraform Files Referenced

### `/Users/nando/Dev/hotel/app-demo/terraform_content/schema.sql`
- **548 lines** of PostgreSQL DDL + seed data
- **Tables:** `users`, `properties`, `rooms`, `media`, `property_amenities`, `room_amenities`, `property_amenities_link`, `room_amenities_link`
- **Indexes:** B-tree on status, property_id, room_id; GIN trigram indexes on city and name for ILIKE search; `pg_trgm` extension
- **Seed data:** 1 user (Jack Torrance), 10 properties (famous fictional hotels), 10 property amenities, 6 room amenities, 19 rooms, all amenity linkages, 16 media records with S3 URLs
- **Referenced in `storage.tf`** via `${path.module}/schema.sql`

### `/Users/nando/Dev/hotel/app-demo/terraform_content/seed_media/`
- **17 PNG images** for hotel property photos
- Files: `prop01_front.png` through `prop10_hall.png`
- Coverage: 10 properties, with some having multiple images (front, hall, interior, pool)
- **Referenced in `storage.tf`** via `${path.module}/seed_media/{filename}`

**Important note on file resolution:** The Terraform code references these files as `${path.module}/schema.sql` and `${path.module}/seed_media/...`, which resolves to the `terraform/` directory. However, on the host filesystem, these files physically exist at `../terraform_content/`. The `terraform/` directory is mounted into LocalStack at `/etc/localstack/init/ready.d`. At container runtime, `schema.sql` and `seed_media/` must be present at the same level as the `.tf` files for Terraform to find them. This suggests either a Docker build step or volume mount that is not captured in the current `docker-compose.yml` makes these files available, or they are expected to be manually copied/symlinked before running.

---

## 3. Complete Outputs Summary (20 total)

| Output | File | Value |
|---|---|---|
| `vpc_id` | `network.tf` | VPC ID |
| `public_subnet_ids` | `network.tf` | List of 2 public subnet IDs |
| `private_subnet_ids` | `network.tf` | List of 2 private subnet IDs |
| `private_dns_zone_id` | `network.tf` | Route53 zone ID |
| `alb_dns_name` | `compute.tf` | ALB DNS name |
| `s3_frontend_endpoint` | `storage.tf` | S3 website URL |
| `s3_frontend_bucket_name` | `storage.tf` | `my-app-frontend-bucket-local` |
| `s3_media_bucket_name` | `storage.tf` | `my-app-media-assets-local` |
| `s3_media_bucket_url` | `storage.tf` | `http://localstack:4566/{bucket}` |
| `rds_endpoint` | `storage.tf` | RDS host:port |
| `rds_db_name` | `storage.tf` | `myappdb` |
| `security_group_alb_id` | `security.tf` | ALB SG ID |
| `security_group_ec2_id` | `security.tf` | EC2 SG ID |
| `security_group_db_id` | `security.tf` | DB SG ID |
| `cognito_user_pool_id` | `identity.tf` | Cognito pool ID |
| `cognito_client_id` | `identity.tf` | Cognito client ID |
| `cognito_issuer_url` | `identity.tf` | Cognito issuer URL |
| `api_gateway_endpoint` | `gateway.tf` | API Gateway URL |
| `cloudfront_domain_name` | `frontend_distribution.tf` | CloudFront domain |
| `cloudfront_id` | `frontend_distribution.tf` | CloudFront distribution ID |

---

## 4. Variables Summary (2 total)

| Variable | Default | Used In |
|---|---|---|
| `aws_region` | `"us-east-1"` | `main.tf` (.env), `identity.tf` (issuer URL), `gateway.tf` (authorizer) |
| `db_password` | `"test"` | `storage.tf` (RDS password), `main.tf` (.env) |

---

## 5. Locals Summary (1 block)

| Local | File | Description |
|---|---|---|
| `media_files` | `storage.tf` | Map of 17 entries: S3 key -> local file path for seed images |

---

## 6. SSH Key Pair Setup

**There is no SSH key pair configuration.** No `aws_key_pair` resource, no `key_name` attribute on any EC2 instance or launch template, and no SSH key references anywhere in the codebase. SSH access to EC2 instances would rely on LocalStack's container-based access (`docker exec`) rather than traditional SSH key authentication.

---

## 7. S3 Media Seeding (Detailed)

The S3 seeding uses a **`for_each` pattern with a locals map**:

1. **`locals.media_files`** (in `storage.tf`, lines 202-222) defines a map of 17 image files, mapping:
   - S3 object keys (e.g., `"prop01/front.png"`, `"prop03/interior.png"`) to
   - Local file paths (e.g., `"${path.module}/seed_media/prop01_front.png"`)

2. **`aws_s3_object.media_seed`** (lines 224-239) iterates over the map with `for_each`:
   - `bucket` = media bucket ID
   - `key` = `each.key` (the S3 path like `prop01/front.png`)
   - `source` = `each.value` (the local file path)
   - `content_type` = dynamically determined via `lookup()` on the file extension (png -> `image/png`, jpg/jpeg -> `image/jpeg`, fallback `application/octet-stream`)

3. **S3 key structure:** Files are organized by property in folders: `prop01/`, `prop02/`, ..., `prop10/`, with image names like `front.png`, `hall.png`, `interior.png`, `pool.png`.

4. **Database integration:** The `schema.sql` seed data contains matching `media` table records that reference these S3 objects using the URL pattern `http://localstack:4566/my-app-media-assets-local/{key}`.

---

## 8. DB Seeding (Detailed)

The database seeding uses a **`null_resource` with `local-exec` provisioner**:

1. **`null_resource.db_setup`** (lines 145-163):
   - **Triggers:** Re-executes if `schema.sql` file hash changes (`filemd5()`) or the DB instance ID changes
   - **Depends on:** `aws_db_instance.postgres`
   - **Provisioner:** Runs `psql` via `local-exec` with:
     - `PGPASSWORD` environment variable set from the RDS password
     - Connects to `localhost:4510` (LocalStack's mapped RDS port)
     - Executes the full `schema.sql` file (DDL + seed data)
     - Includes a `sleep 5` to wait for DB readiness

---

## 9. Architecture Summary

```
Internet
   |
CloudFront (CDN) --- S3 Frontend Bucket (static SPA)
   |
API Gateway (HTTP, JWT auth via Cognito)
   |
   |--- Public: GET /api/search, OPTIONS
   |--- Protected: ANY /{proxy+} (JWT required)
   |
Backend Integration (http://backend:8000, Docker DNS)
   |
ALB (public subnets) --- [not actively used for API routing in LocalStack]
   |
ASG (2 EC2 instances in private subnets)
   |
RDS PostgreSQL (private subnets, port 5432)
   |
S3 Media Bucket (private, IAM-controlled access)
   |
Cognito User Pool (authentication, OWNERS group)
```

The `.env` file generated by Terraform at `/config/localstack.env` is the glue that connects all services, shared via a Docker named volume (`localstack_env`) to the backend and frontend containers.
</task_result>
```

---

## Assistant (Build · claude-opus-4.6 · 76.4s)

Now I have a thorough understanding of both the requirements and the existing codebase. Let me create the plan.

**Tool: write**

**Input:**
```json
{
  "filePath": "/Users/nando/Dev/hotel/app-demo/terraform/PLAN.md",
  "content": "# Piano di Migrazione: AWS (LocalStack) -> OpenStack (DevStack)\n\n## Panoramica\n\nTradurre l'infrastruttura Terraform attualmente destinata ad AWS/LocalStack in una\nconfigurazione equivalente per OpenStack/DevStack, mantenendo la struttura a 3 livelli\n(frontend, backend, database) con un bastion host per l'accesso SSH.\n\n---\n\n## Vincoli dell'Ambiente Target\n\n| Aspetto | Dettaglio |\n|---|---|\n| Host | Windows |\n| Guest VM | Linux, 75GB disco, 6 vCPU, 32GB RAM |\n| OpenStack | DevStack `stable/2025.1` |\n| Servizi attivi | Nova, Neutron (OVN), Octavia (OVN provider), Swift, Keystone, Glance, Horizon |\n| Servizi **non** attivi | Octavia Amphora (disabilitato), Heat, Barbican, Designate, Cinder (default DevStack) |\n| Autenticazione | `clouds.yaml` |\n\n---\n\n## Mappatura AWS -> OpenStack\n\n| AWS Resource | OpenStack Equivalent | Note |\n|---|---|---|\n| VPC + Subnets | `openstack_networking_network_v2` + `openstack_networking_subnet_v2` | Singola rete privata `10.0.1.0/24` |\n| Internet Gateway + Route Table | `openstack_networking_router_v2` + `openstack_networking_router_interface_v2` | Router collegato alla rete esterna |\n| ALB (Application Load Balancer) | `openstack_lb_loadbalancer_v2` (Octavia, provider OVN) | Layer 4 TCP, non Layer 7 |\n| ASG + Launch Template | Istanze Nova individuali | OpenStack non ha ASG nativo; useremo istanze statiche |\n| EC2 Instances | `openstack_compute_instance_v2` | Con cloud-init e keypair |\n| Security Groups | `openstack_networking_secgroup_v2` + `openstack_networking_secgroup_rule_v2` | Regole equivalenti |\n| S3 Bucket | `openstack_objectstorage_container_v1` (Swift) | Solo per media assets |\n| S3 Object | `openstack_objectstorage_object_v1` (Swift) | Seed delle immagini |\n| RDS PostgreSQL | Istanza Nova con cloud-init PostgreSQL | DevStack non ha Trove; il DB gira su una VM |\n| IAM Roles/Policies | `openstack_identity_role_v3` + `openstack_identity_user_v3` + ACL Swift | Ruoli Keystone + ACL sul container |\n| Cognito | **Eliminato** | Nessun equivalente diretto in DevStack |\n| API Gateway | **Eliminato** | Nessun equivalente diretto in DevStack |\n| CloudFront | **Eliminato** | Nessun equivalente diretto in DevStack |\n| Route53 | **Eliminato** | Designate non abilitato in DevStack |\n| AMI | `openstack_images_image_v2` (Glance) | Ubuntu Jammy cloud image |\n| Key Pair | `openstack_compute_keypair_v2` | Chiave SSH generata da Terraform |\n\n---\n\n## Risorse da NON Migrare\n\nI seguenti servizi AWS non hanno equivalenti nel DevStack target e verranno omessi:\n\n1. **Cognito** (identity.tf) -- nessun IdP in DevStack\n2. **API Gateway** (gateway.tf) -- nessun API gateway in DevStack\n3. **CloudFront** (frontend_distribution.tf) -- nessun CDN in DevStack\n4. **Route53** (parte di network.tf) -- Designate non abilitato\n5. **CloudWatch Alarms** (parte di compute.tf) -- nessun equivalente\n6. **Auto Scaling Group** (parte di compute.tf) -- nessun equivalente nativo\n\n---\n\n## File da Creare/Modificare\n\nMantenendo la convenzione di organizzazione per dominio del progetto originale:\n\n| File | Contenuto |\n|---|---|\n| `main.tf` | Blocco `terraform`, provider `openstack`, generazione file `.env` |\n| `variables.tf` | Tutte le variabili di input centralizzate |\n| `network.tf` | Rete privata, subnet, router, floating IPs |\n| `security.tf` | Security groups: Bastion, Frontend, Backend, Database |\n| `compute.tf` | Flavor, immagine Glance, keypair, 5 istanze Nova |\n| `storage.tf` | Container Swift, upload seed media, ruoli/utenti Keystone |\n| `cloud-init/frontend-init-node.yaml` | Template cloud-init per nodi frontend |\n| `cloud-init/backend-init-node.yaml` | Template cloud-init per nodo backend |\n| `cloud-init/cloud-init-db.yaml` | Template cloud-init per nodo database |\n\nFile da **rimuovere** (non applicabili a OpenStack):\n\n| File | Motivo |\n|---|---|\n| `iam.tf` | Sostituito da ruoli Keystone in `storage.tf` |\n| `identity.tf` | Cognito non ha equivalente |\n| `gateway.tf` | API Gateway non ha equivalente |\n| `frontend_distribution.tf` | CloudFront non ha equivalente |\n\n---\n\n## Piano di Implementazione Step-by-Step\n\n### Step 0: Pulizia e Setup\n\n- Rimuovere tutti i file `.tf` esistenti (sono specifici AWS)\n- Creare la directory `cloud-init/` per i file di configurazione\n- Copiare i file seed_media dal percorso corrente (se presenti)\n\n### Step 1: `main.tf` -- Provider e Configurazione Base\n\n- Blocco `terraform` con `required_providers` per `openstack` (ultima versione)\n- Provider `openstack` con autenticazione via `clouds.yaml` (nessuna credenziale hardcoded)\n- Risorsa `local_file` per generare un `.env` con gli output dell'infrastruttura\n\n### Step 2: `variables.tf` -- Variabili\n\nVariabili da definire:\n- `external_network_name` (default: `\"public\"`) -- rete esterna DevStack\n- `dns_nameservers` (default: `[\"8.8.8.8\"]`)\n- `db_password` (default: `\"test\"`) -- password PostgreSQL\n- `db_user` (default: `\"dbadmin\"`)\n- `db_name` (default: `\"myappdb\"`)\n- `image_url` (default: URL cloud image Ubuntu Jammy)\n- `keypair_private_key_path` (default: `\"~/.ssh/hotel-key.pem\"`)\n\n### Step 3: `network.tf` -- Rete e Router\n\nRisorse:\n- `openstack_networking_network_v2.hotel_net` -- rete privata `hotel-private-net`\n- `openstack_networking_subnet_v2.hotel_subnet` -- subnet `10.0.1.0/24`, DHCP abilitato, DNS nameservers\n- `data.openstack_networking_network_v2.external` -- riferimento alla rete esterna\n- `openstack_networking_router_v2.hotel_router` -- router con gateway esterno\n- `openstack_networking_router_interface_v2.router_iface` -- interfaccia router-subnet\n- `openstack_networking_floatingip_v2.bastion_fip` -- floating IP per bastion\n- `openstack_networking_floatingip_v2.lb_fip` -- floating IP per load balancer\n- `openstack_compute_floatingip_associate_v2.bastion_fip_assoc` -- associazione FIP al bastion\n\nOutput: `network_id`, `subnet_id`, `router_id`, `bastion_floating_ip`, `lb_floating_ip`\n\n### Step 4: `security.tf` -- Security Groups\n\n4 security groups con regole di segmentazione rigorosa:\n\n1. **`bastion_sg`** -- Bastion Security Group\n   - Ingress: TCP/22 da `0.0.0.0/0`\n   - Egress: tutto\n\n2. **`frontend_sg`** -- Frontend Security Group\n   - Ingress: TCP/80 da `0.0.0.0/0` (traffico HTTP dal LB)\n   - Ingress: TCP/22 da `bastion_sg` (accesso SSH via bastion)\n   - Egress: tutto\n\n3. **`backend_sg`** -- Backend Security Group\n   - Ingress: TCP/80 da `frontend_sg` (API REST)\n   - Ingress: TCP/22 da `frontend_sg` (accesso SSH via frontend)\n   - Egress: tutto\n\n4. **`database_sg`** -- Database Security Group\n   - Ingress: TCP/5432 da `backend_sg` (PostgreSQL)\n   - Egress: tutto\n\nOutput: gli ID dei 4 security groups\n\n### Step 5: `compute.tf` -- Flavor, Immagine, Keypair e Istanze\n\nRisorse:\n\n- **Glance Image**: `openstack_images_image_v2.ubuntu_jammy`\n  - `image_source_url` per scaricare `jammy-server-cloudimg-amd64.img`\n  - `container_format = \"bare\"`, `disk_format = \"qcow2\"`\n\n- **Flavor**: `openstack_compute_flavor_v2.hotel_flavor`\n  - 1 vCPU, 2048 MB RAM, 10 GB disco\n\n- **Keypair**: `tls_private_key` + `openstack_compute_keypair_v2.hotel_keypair`\n  - Generazione chiave RSA tramite provider `tls`\n  - Salvataggio chiave privata in `~/.ssh/hotel-key.pem` via `local_file`\n\n- **Istanze** (5 totali):\n  1. `openstack_compute_instance_v2.frontend[0]` -- Frontend 1\n  2. `openstack_compute_instance_v2.frontend[1]` -- Frontend 2\n  3. `openstack_compute_instance_v2.backend` -- Backend\n  4. `openstack_compute_instance_v2.database` -- Database\n  5. `openstack_compute_instance_v2.bastion` -- Bastion (immagine cirros)\n  - Tutte nella rete `hotel-private-net`, con i rispettivi security groups\n  - Cloud-init via `user_data` per le istanze Ubuntu\n\nOutput: IP delle istanze, ID del keypair\n\n### Step 6: Cloud-Init Files\n\n3 file di configurazione cloud-init:\n\n1. **`cloud-init/frontend-init-node.yaml`**\n   - Installa `nginx` (o usa python http.server)\n   - Configura una pagina HTML statica: `Frontend node {i}`\n   - Avvia il servizio HTTP sulla porta 80\n   - Sarà templatizzato con `templatefile()` per iniettare l'indice del nodo\n\n2. **`cloud-init/backend-init-node.yaml`**\n   - Installa `python3`, `pip`, `fastapi`, `uvicorn`\n   - Crea un semplice server FastAPI\n   - Avvia uvicorn sulla porta 80\n\n3. **`cloud-init/cloud-init-db.yaml`**\n   - Installa `postgresql`\n   - Configura `pg_hba.conf` per accettare connessioni dalla subnet\n   - Configura `postgresql.conf` per ascoltare su tutte le interfacce\n   - Crea utente e database\n   - Esegue lo schema SQL per il seeding\n\n### Step 7: `storage.tf` -- Swift, Keystone e Seeding\n\nRisorse:\n\n- **Swift Container**: `openstack_objectstorage_container_v1.hotel_assets`\n  - Nome: `hotel-assets`\n\n- **Keystone Roles**:\n  - `openstack_identity_role_v3.media_reader`\n  - `openstack_identity_role_v3.media_uploader`\n\n- **Keystone Users**:\n  - `openstack_identity_user_v3.app_frontend_reader`\n  - `openstack_identity_user_v3.app_frontend_uploader`\n\n- **Role Assignments**: Binding dei ruoli agli utenti sul progetto\n\n- **Container ACLs**: Read/Write ACL sul container Swift usando i ruoli creati\n\n- **Seed Media**: `openstack_objectstorage_object_v1.media_seed`\n  - Upload delle 17 immagini via `for_each` (stessa logica dell'AWS originale)\n\n- **Secrets/`.env`**: Generazione file `.env` con credenziali e endpoint (tramite `local_file` in `main.tf`)\n  - Le password degli utenti Keystone saranno generate con `random_password`\n  - Nessun segreto hardcoded negli output\n\nOutput: nome container Swift, endpoint\n\n### Step 8: Load Balancer (in `network.tf` o file dedicato)\n\nRisorse da aggiungere a `network.tf`:\n\n- `openstack_lb_loadbalancer_v2.hotel_lb` -- LB Octavia con `loadbalancer_provider = \"ovn\"`, sulla subnet privata\n- `openstack_lb_listener_v2.http_listener` -- Listener TCP porta 80\n- `openstack_lb_pool_v2.frontend_pool` -- Pool con algoritmo `SOURCE_IP_PORT`\n- `openstack_lb_member_v2.frontend_member[0]` -- Membro pool (frontend 1, porta 80)\n- `openstack_lb_member_v2.frontend_member[1]` -- Membro pool (frontend 2, porta 80)\n- `openstack_lb_monitor_v2.tcp_monitor` -- Health monitor TCP (delay 5s, timeout 3s, max_retries 3)\n- Associazione floating IP al VIP del LB\n\n---\n\n## Ordine delle Dipendenze\n\n```\nStep 1 (main.tf)\n  |\nStep 2 (variables.tf)\n  |\nStep 3 (network.tf) -- rete, subnet, router\n  |\nStep 4 (security.tf) -- SGs (dipendono dalla rete)\n  |\nStep 5 (compute.tf) -- immagine, flavor, keypair, istanze\n  |          |                    (dipendono da rete + SGs)\n  |          |\nStep 6 (cloud-init/) -- file cloud-init referenziati da compute\n  |\nStep 7 (storage.tf) -- Swift, Keystone users/roles, seed\n  |\nStep 8 (LB in network.tf) -- Load Balancer (dipende da subnet + istanze frontend)\n  |\nFinal: `.env` generation in main.tf (dipende da tutti gli output)\n```\n\n---\n\n## Rischi e Considerazioni\n\n1. **Octavia OVN Provider**: Con `OCTAVIA_USE_AMPHORA_PROVIDER=False`, il LB usa il provider OVN nativo. Il metodo `SOURCE_IP_PORT` potrebbe non essere supportato dal provider OVN -- verificare e usare `SOURCE_IP` come fallback.\n\n2. **Floating IP sul VIP**: L'associazione di una floating IP al VIP del Load Balancer OVN richiede `openstack_networking_floatingip_associate_v2` con il `port_id` del VIP -- attenzione alla sequenza di dipendenze.\n\n3. **Cloud Image Download**: Il download dell'immagine Ubuntu Jammy (~700MB) via `image_source_url` potrebbe richiedere tempo e la VM DevStack deve avere accesso a internet.\n\n4. **Risorse limitate**: Con 6 vCPU e 32GB RAM totali per DevStack, 5 VM con il flavor `hotel_flavor` (1 vCPU, 2GB RAM ciascuna) consumano 5 vCPU e 10GB RAM -- verificare che rimanga sufficiente per i servizi OpenStack.\n\n5. **Cloud-init su cirros**: Il bastion usa l'immagine `cirros` che ha supporto cloud-init molto limitato. Non verrà configurato con cloud-init personalizzato.\n\n6. **Seeding del DB**: A differenza dell'originale che usa `psql` via `local-exec`, qui il seeding avverrà via cloud-init embedded nel file YAML del nodo database, poiche la VM non sara raggiungibile direttamente dalla macchina che esegue Terraform.\n\n7. **Nessun segreto negli output**: Le password saranno generate con `random_password` e scritte solo nel file `.env` locale, mai esposte come output Terraform.\n"
}
```

**Output:**
```
Wrote file successfully.
```

---

## Assistant (Build · claude-opus-4.6 · 9.9s)

The plan is ready at `PLAN.md`. Here's a summary of what it covers:

**What gets migrated:**
- VPC/Subnets -> Neutron network + subnet (`10.0.1.0/24`) + router
- EC2/ASG -> 5 Nova instances (2 frontend, 1 backend, 1 database, 1 bastion)
- ALB -> Octavia LB with OVN provider (Layer 4 TCP)
- S3 -> Swift container with seed media upload
- IAM -> Keystone roles (`media_reader`, `media_uploader`) + users + Swift ACLs
- Security Groups -> 4 Neutron SGs (bastion, frontend, backend, database)
- SSH Key -> `tls_private_key` + `openstack_compute_keypair_v2`
- Glance image for Ubuntu Jammy + cirros for bastion

**What gets dropped** (no OpenStack equivalent in DevStack):
- Cognito, API Gateway, CloudFront, Route53, CloudWatch, Auto Scaling

**Key decisions:**
- DB runs on a Nova instance with PostgreSQL installed via cloud-init (no Trove)
- DB seeding is embedded in cloud-init (Terraform can't reach the VM directly)
- Secrets use `random_password` and are only written to a `.env` file, never exposed in outputs
- `SOURCE_IP_PORT` used for LB algorithm with `SOURCE_IP` as documented fallback
- File organization follows the existing domain-based convention

**8 implementation steps** with dependency ordering and 7 identified risks.

Please review the plan and let me know if you'd like any changes before I start writing code.

---

