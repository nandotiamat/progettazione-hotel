terraform {
  required_version = ">= 1.3.0"
}

locals {
  # Inventory of what the current AWS(LocalStack) Terraform does.
  # This file is documentation-as-code only; it does not provision anything.
  aws_stack_inventory = {
    networking = {
      files = [
        "network.tf",
      ]
      features = [
        "VPC",
        "public/private subnets",
        "internet gateway",
        "route tables",
        "Route53 private zone",
        "LocalStack default VPC/subnets/SG references for debug",
      ]
    }

    security = {
      files = [
        "security.tf",
      ]
      features = [
        "security groups for ALB, EC2, DB",
        "extra ingress rules on default SG for LocalStack port mapping",
      ]
    }

    compute = {
      files = [
        "compute.tf",
      ]
      features = [
        "application load balancer",
        "target group + listener",
        "launch template",
        "autoscaling group",
        "CloudWatch alarm + scaling policy",
        "manual debug EC2 instance (port 8000)",
      ]
    }

    storage = {
      files = [
        "storage.tf",
        "frontend_distribution.tf",
      ]
      features = [
        "S3 frontend bucket (static website)",
        "S3 media bucket",
        "S3 object seeding (seed_media/*)",
        "CloudFront distribution (SPA-friendly error responses)",
      ]
    }

    database = {
      files = [
        "storage.tf",
      ]
      features = [
        "RDS Postgres",
        "subnet group",
        "schema initialization via null_resource + local-exec (psql)",
      ]
    }

    identity_and_api = {
      files = [
        "identity.tf",
        "gateway.tf",
      ]
      features = [
        "Cognito user pool/client/domain/groups",
        "API Gateway v2 HTTP API",
        "JWT authorizer (Cognito)",
        "HTTP proxy integration to backend:8000",
      ]
    }

    iam = {
      files = [
        "iam.tf",
      ]
      features = [
        "IAM role/policy/profile for backend",
        "S3 media bucket access",
      ]
    }

    local_integration = {
      files = [
        "main.tf",
      ]
      features = [
        "AWS provider configured for LocalStack endpoints",
        "local_file writes /config/localstack.env for other components",
      ]
    }
  }

  # Features that cannot be replicated 1:1 in the target DevStack
  # (Neutron+OVN, Swift, Octavia) without enabling additional OpenStack services.
  not_one_to_one_in_devstack = [
    "Cognito user pools/groups and managed JWT authorizer behavior",
    "API Gateway v2 routing/authorizers/integrations",
    "CloudFront CDN distribution",
    "Route53 private hosted zone (unless Designate is enabled)",
    "RDS managed Postgres (unless Trove is enabled)",
    "ASG + CloudWatch alarms-based autoscaling (unless Senlin/Aodh are enabled)",
  ]

  # Preliminary mapping hints (full mapping is Step 2).
  mapping_hints = {
    "VPC/Subnets/Routes" = "Neutron network/subnet/router"
    "Security Groups"    = "Neutron security groups/rules"
    "ALB"                = "Octavia LB"
    "S3"                 = "Swift"
    "RDS"                = "Postgres on Nova VM (or Trove if enabled)"
    "Cognito/APIGW"      = "Direct LB routing + app-level auth"
    "Route53"            = "Omit or Designate (if enabled)"
    "CloudFront"         = "Omit (optional proxy/caching layer)"
    "ASG/CloudWatch"     = "Fixed instance count (manual scaling)"
  }
}

output "aws_stack_inventory" {
  value       = local.aws_stack_inventory
  description = "Documentation-only inventory of the current AWS(LocalStack) Terraform stack."
}

output "not_one_to_one_in_devstack" {
  value       = local.not_one_to_one_in_devstack
  description = "AWS features without 1:1 equivalents in constrained DevStack."
}

output "mapping_hints" {
  value       = local.mapping_hints
  description = "High-level AWS->OpenStack mapping hints (Step 1 only)."
}
