# Migration Plan: AWS (LocalStack) to OpenStack (DevStack)

## Phase 1: Resource Mapping & Feasibility Analysis
The first step is to analyze the existing AWS Terraform files and map them to their OpenStack equivalents, keeping the DevStack constraints in mind (6 vCPUs, 32GB RAM, specific enabled plugins).

* **`main.tf` (Provider):** Replace the AWS provider (LocalStack config) with the OpenStack provider (`terraform-provider-openstack/openstack`), pointing to the DevStack Keystone endpoint (`http://192.168.1.13/identity/v3`).
* **`network.tf` (VPC/Subnets):** Map AWS VPCs, Subnets, Internet Gateways, and Route Tables to Neutron Networks, Subnets, and Routers.
* **`security.tf` (Security Groups/WAF/KMS):** Map AWS Security Groups to Neutron Security Groups. Discard WAF/KMS as DevStack does not have direct equivalents configured here (no Barbican enabled).
* **`storage.tf` (S3/DynamoDB):** Map AWS S3 buckets to OpenStack Swift containers (Swift is explicitly enabled in `local.conf`). If DynamoDB exists, it will need to be replaced by an instance running a DB, or mocked.
* **`compute.tf` (EC2/ECS/Lambda):** Map compute resources to Nova Instances. Given the 6 vCPU constraint of the guest VM, we will use minimal flavors (e.g., `m1.nano` or `m1.micro`) and combine services where possible to avoid exhausting host resources. 
* **`gateway.tf` & `frontend_distribution.tf` (ALB/API GW/CloudFront):** Map load balancing and ingress to Octavia Load Balancers. Since `OCTAVIA_USE_AMPHORA_PROVIDER=False` is set, Octavia will use the OVN provider natively without spinning up heavy Amphora VMs. CloudFront/API Gateway features will be simplified to standard LBaaS VIPs (Floating IPs).
* **`iam.tf` & `identity.tf` (IAM/Cognito):** AWS IAM roles/profiles will be mapped to Keystone users/projects or standard OpenStack Keypairs/Application Credentials, as OpenStack handles instance permissions differently. Cognito will be removed or mocked as Keystone doesn't fully replace Cognito's end-user identity pool functionality out of the box.

## Phase 2: Provider & Variables Setup
1. Refactor `main.tf` to configure the OpenStack provider.
2. Update `variables.tf` to include OpenStack-specific variables (e.g., `auth_url`, `tenant_name`, `user_name`, `password`, `region`). Defaults will target the DevStack environment (`admin`/`secret` or `demo`/`secret`).

## Phase 3: Infrastructure Translation (Step-by-Step Implementation)
*I will proceed with these files sequentially, asking for reviews if necessary.*

1. **Network Configuration (`network.tf`, `security.tf`)**
   * Create the external network data source.
   * Create the tenant router, network, and subnet (matching DevStack's MTU of 1450).
   * Translate Security Groups to `openstack_networking_secgroup_v2` and `openstack_networking_secgroup_rule_v2`.

2. **Storage Configuration (`storage.tf`)**
   * Convert `aws_s3_bucket` resources to `openstack_objectstorage_container_v1` (Swift).

3. **Compute & Load Balancing (`compute.tf`, `gateway.tf`, `frontend_distribution.tf`)**
   * Create Nova Keypairs.
   * Provision Nova Instances (`openstack_compute_instance_v2`) using lightweight images (e.g., CirrOS or minimal Ubuntu/Alpine) via `cloud-init`.
   * Create Octavia Load Balancers (`openstack_lb_loadbalancer_v2`), Listeners, Pools, and Members to route traffic to the Nova instances. Attach a Floating IP to the LB VIP.

4. **Identity/IAM Scrubbing (`iam.tf`, `identity.tf`)**
   * Clean up AWS-specific IAM attachments. If any instances needed access to Swift, configure them via Keystone app credentials passed via user-data.

## Phase 4: Validation & Refinement
1. Run `terraform fmt` and `terraform validate` after each major file translation.
2. Review the combined footprint. If the plan provisions more than 4-5 small instances, we will consolidate them to avoid breaking the 6 vCPU guest constraint.
3. Final review of the plan against the OVN and Swift configurations specified in the DevStack `local.conf`.

---
*Awaiting your approval to begin executing Phase 1 and generating the Terraform code.*