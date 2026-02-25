# Step 1: Provider & Skeleton (`main.tf`)

## Goal

Replace the `hashicorp/aws` provider (targeting LocalStack) with the `terraform-provider-openstack/openstack` provider targeting a DevStack `stable/2025.1` environment. Establish the foundational `main.tf` and a minimal `variables.tf` skeleton to support subsequent steps.

## Rationale

The OpenStack provider v3.x is the latest stable line from `terraform-provider-openstack/openstack` and supports all the resources needed for this migration (Neutron networking, Nova compute, Swift object storage, Octavia load balancing, Keystone identity). The provider is configured with DevStack defaults: `auth_url` pointing to the Keystone identity endpoint, admin credentials, and `insecure = true` since DevStack typically uses self-signed certificates.

A minimal `variables.tf` was created alongside `main.tf` because the provider block references variables (`var.os_auth_url`, `var.os_user_name`, etc.) and Terraform validation would fail without them. This file will be expanded in Step 13 with any additional variables discovered during implementation.

## Alternatives

1. **Hardcoded credentials in the provider block** — Simpler but less flexible and violates the DRY principle. Rejected in favor of variables with defaults for consistency with the original project's pattern.
2. **Using `clouds.yaml`** — OpenStack's native credential file. While idiomatic for OpenStack tooling, it adds external file dependency and diverges from the original project's self-contained Terraform approach. Rejected for simplicity.
3. **Provider version `~> 2.0`** — Older line, still available. Rejected because v3.x is actively maintained and has better resource coverage for modern OpenStack services like Octavia with OVN.
