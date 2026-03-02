locals {
  # Step 2 mapping: AWS(LocalStack) -> OpenStack(DevStack) equivalents.
  # Target DevStack components: Neutron+OVN, Swift, Octavia.

  capability_matrix = {
    networking = {
      aws = [
        "VPC",
        "subnets",
        "route tables",
        "internet gateway",
      ]
      openstack = [
        "Neutron network",
        "Neutron subnet",
        "Neutron router + interface",
        "Neutron router external gateway",
      ]
      status = "supported"
      notes  = "Model as one tenant network/subnet and a router to the external network."
    }

    security_groups = {
      aws       = ["EC2 security groups"]
      openstack = ["Neutron security groups + rules"]
      status    = "supported"
      notes     = "Use SGs for backend and DB; restrict access by source SG."
    }

    load_balancing = {
      aws       = ["ALB"]
      openstack = ["Octavia load balancer"]
      status    = "supported"
      notes     = "Use an HTTP listener/pool with members = backend instances. Floating IP for VIP for external access."
    }

    autoscaling = {
      aws       = ["ASG", "launch template", "CloudWatch alarms/policies"]
      openstack = ["Fixed instance count"]
      status    = "workaround"
      notes     = "DevStack does not enable Senlin/Aodh by default; emulate with count and document manual scaling."
    }

    object_storage = {
      aws       = ["S3 buckets", "S3 objects"]
      openstack = ["Swift containers", "Swift objects"]
      status    = "supported"
      notes     = "Create containers for frontend/media; optional object upload via Terraform if local seed path exists."
    }

    cdn = {
      aws       = ["CloudFront distribution"]
      openstack = []
      status    = "omitted"
      notes     = "No CDN in base DevStack; omit. Optional proxy/cache VM is out of scope for this port."
    }

    managed_database = {
      aws       = ["RDS Postgres"]
      openstack = ["Postgres on Nova VM"]
      status    = "workaround"
      notes     = "Trove is not enabled; provision a DB VM and initialize via cloud-init."
    }

    dns_private_zone = {
      aws       = ["Route53 private hosted zone"]
      openstack = []
      status    = "omitted"
      notes     = "Designate is typically not enabled in DevStack; rely on outputs and/or /etc/hosts."
    }

    identity_and_api_gateway = {
      aws       = ["Cognito", "API Gateway v2 HTTP API + JWT authorizer"]
      openstack = []
      status    = "omitted"
      notes     = "No direct equivalents in this DevStack profile. Route through Octavia LB; auth becomes app responsibility."
    }
  }
}

output "capability_matrix" {
  value       = local.capability_matrix
  description = "Supported/workaround/omitted matrix for the OpenStack port."
}
