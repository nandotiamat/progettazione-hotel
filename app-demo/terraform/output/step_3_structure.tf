locals {
  # Step 3 structure: proposed Terraform root module layout for the OpenStack port.
  # This is a plan artifact that the next steps will implement.

  target_file_layout = [
    {
      path    = "provider.tf"
      purpose = "OpenStack provider configuration; optional clouds.yaml support; required providers block."
    },
    {
      path    = "variables.tf"
      purpose = "All inputs (auth, image/flavor/keypair, network names/CIDRs, counts, ports) with validation."
    },
    {
      path    = "network.tf"
      purpose = "Neutron tenant network/subnet, router, router interface, external gateway; optionally floating IP pool lookup."
    },
    {
      path    = "security.tf"
      purpose = "Neutron security groups and rules for backend, DB, optional SSH ingress."
    },
    {
      path    = "compute_backend.tf"
      purpose = "Backend instance group via count; ports for app; attach SG; cloud-init for app runtime."
    },
    {
      path    = "compute_db.tf"
      purpose = "DB instance (Postgres) + cloud-init initialization; optional Cinder volume."
    },
    {
      path    = "lb.tf"
      purpose = "Octavia LB: loadbalancer, listener, pool, members, health monitor; floating IP association for VIP."
    },
    {
      path    = "swift.tf"
      purpose = "Swift containers for frontend/media; optional objects upload if seed paths exist."
    },
    {
      path    = "env_file.tf"
      purpose = "Generate a dotenv-style file with endpoints/IDs for downstream components (replaces /config/localstack.env)."
    },
    {
      path    = "outputs.tf"
      purpose = "Expose LB endpoint, instance IPs, DB endpoint, Swift container names, and env file path."
    },
  ]
}

output "target_file_layout" {
  value       = local.target_file_layout
  description = "Proposed file structure for the OpenStack Terraform root module."
}
