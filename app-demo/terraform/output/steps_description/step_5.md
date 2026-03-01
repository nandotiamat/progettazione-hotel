# Step 5: network.tf — Rete, Subnet, Router, Floating IPs

## Goal

Create the complete networking layer: a private network with a subnet (10.0.1.0/24), a router connected to DevStack's external network for internet access, and two floating IPs (one for the bastion host, one for the load balancer).

## Rationale

- **Single flat network** (`hotel-private-net`) with one subnet matches the original AWS architecture (single VPC with subnets). DevStack doesn't need the multi-AZ subnet pattern that AWS uses.
- **DHCP enabled** on the subnet so instances get IPs automatically via Neutron — no need for manual IP assignment.
- **DNS nameservers** from variable (`8.8.8.8` default) ensures cloud-init can resolve package repositories during instance provisioning.
- **Router with external gateway** provides NAT for outbound traffic from the private subnet (critical for cloud-init package downloads) and serves as the gateway for floating IP routing.
- **Two floating IPs** allocated from the external pool: one for bastion SSH access, one for the LB's public-facing VIP. The actual associations happen in `compute.tf` (bastion) and `loadbalancer.tf` (LB) respectively.

## Alternatives

1. **Multiple subnets (public/private)** — AWS pattern with public and private subnets. Unnecessary in OpenStack since floating IPs handle external access without a separate "public" subnet.
2. **Static IP allocation** — Using `fixed_ip_v4` on instances instead of DHCP. More fragile and harder to manage. DHCP is simpler and idiomatic for OpenStack.
3. **Allocating floating IPs in the same file as their association** — Would scatter network resources across files. Keeping allocation in `network.tf` and association in the consuming resource's file follows the dependency flow better.
