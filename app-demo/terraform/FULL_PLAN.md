# Comprehensive Development Plan: AWS to OpenStack (DevStack) Terraform Migration

This document outlines the step-by-step development plan to translate the existing AWS/LocalStack Terraform infrastructure into an OpenStack-native configuration. This assumes the DevStack node is fully operational with all required components (OVN, Swift, Octavia via OVN) installed as per the provided `local.conf`.

## Phase 1: Foundation and Provider Setup
**Files to update:** `main.tf`, `variables.tf`, `outputs.tf` (if exists)

1. **Replace the AWS Provider:**
   * Remove the `hashicorp/aws` provider from `main.tf`.
   * Introduce the `terraform-provider-openstack/openstack` provider.
   * Configure the provider to point to the DevStack Keystone endpoint (e.g., `http://192.168.1.13/identity/v3`).
2. **Update Variables:**
   * Remove AWS-specific variables (like `aws_region`).
   * Add OpenStack authentication variables (`auth_url`, `tenant_name`, `user_name`, `password`, `domain_name`).
   * Default these variables to standard DevStack credentials (e.g., user `admin` or `demo`, password `secret`).

## Phase 2: Core Networking & Security
**Files to update:** `network.tf`, `security.tf`

1. **Translate VPC and Subnets to Neutron:**
   * Map `aws_vpc` to `openstack_networking_network_v2`.
   * Map `aws_subnet` to `openstack_networking_subnet_v2`.
   * Ensure the MTU is set to 1450 (as constrained by the nested virtualization environment in `local.conf`).
2. **Translate Gateways and Routing:**
   * Map `aws_internet_gateway` and route tables to an `openstack_networking_router_v2`.
   * Attach the router to the external public network (usually `public` or `ext-net` in DevStack) and the internal subnet.
3. **Translate Security Groups:**
   * Map `aws_security_group` to `openstack_networking_secgroup_v2`.
   * Map `aws_security_group_rule` to `openstack_networking_secgroup_rule_v2`.
   * Translate AWS ingress/egress rules (ports, CIDRs) directly to Neutron security group rules.

## Phase 3: Object Storage Migration
**Files to update:** `storage.tf`

1. **Translate S3 to Swift:**
   * Map `aws_s3_bucket` to `openstack_objectstorage_container_v1`.
   * Adjust any bucket policies or ACLs to OpenStack Swift container read/write ACLs.
   * *Note: If DynamoDB or other AWS-specific storage is present in the source files, it must be replaced by deploying a compute instance running the database (e.g., PostgreSQL/MySQL or MongoDB), as Trove/DynamoDB alternatives are not enabled in the `local.conf`.*

## Phase 4: Compute Workloads
**Files to update:** `compute.tf`

1. **Translate EC2/ECS/Lambda to Nova Instances:**
   * Replace AWS compute resources with `openstack_compute_instance_v2`.
   * **Constraint Check:** Because the guest VM only has 6 vCPUs and 32GB RAM, we must be extremely frugal. Consolidate microservices into fewer instances if they were separated in AWS ECS/Lambda.
   * Use lightweight flavors (e.g., `m1.nano`, `m1.micro`, or `m1.small`).
   * Use appropriate DevStack images (like CirrOS for testing or a minimal Ubuntu cloud image).
2. **Instance Initialization:**
   * Convert AWS `user_data` (cloud-init) scripts to OpenStack `user_data`.
   * Ensure SSH keys are translated using `openstack_compute_keypair_v2`.

## Phase 5: Load Balancing and Ingress
**Files to update:** `gateway.tf`, `frontend_distribution.tf`

1. **Translate ALB/API Gateway to Octavia:**
   * Map Load Balancers to `openstack_lb_loadbalancer_v2`.
   * Map Listeners to `openstack_lb_listener_v2`.
   * Map Target Groups to `openstack_lb_pool_v2` and `openstack_lb_member_v2`.
   * *Note: Octavia is configured with `OCTAVIA_USE_AMPHORA_PROVIDER=False`, meaning it will use OVN for lightweight, native load balancing without spinning up extra VMs.*
2. **Expose Services:**
   * Allocate an `openstack_networking_floatingip_v2` and attach it to the Octavia Load Balancer VIP to replace CloudFront/API Gateway public endpoints.

## Phase 6: Identity and Access
**Files to update:** `iam.tf`, `identity.tf`

1. **Scrub AWS IAM/Cognito:**
   * OpenStack handles instance permissions differently than AWS IAM Instance Profiles.
   * Remove AWS IAM roles, policies, and attachments.
   * If instances need programmatic access to Swift, create OpenStack Application Credentials and inject them via `user_data`, or rely on TempURLs for Swift.
   * Remove AWS Cognito (as there is no direct equivalent configured in this DevStack). If application-level auth is required, it must be handled at the application layer or mocked.

## Phase 7: Validation and Cleanup
1. **Formatting:** Run `terraform fmt` to ensure the codebase strictly adheres to the HCL formatting guidelines outlined in `AGENTS.md`.
2. **Validation:** Run `terraform validate` to catch any provider-specific syntax errors.
3. **Review:** Perform a final review to ensure the total vCPU count requested by the `openstack_compute_instance_v2` resources does not exceed the 6 vCPU limit of the host VM.