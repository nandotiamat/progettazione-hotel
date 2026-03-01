# Step 6: security.tf — Security Groups e Regole

## Goal

Create four security groups with strict network segmentation between application tiers: bastion (SSH gateway), frontend (HTTP + SSH from bastion), backend (HTTP + SSH from frontend), and database (PostgreSQL from backend only). Each group uses separate `openstack_networking_secgroup_rule_v2` resources for individual rules.

## Rationale

- **Four-tier segmentation** mirrors the original AWS security group design: bastion is the SSH entry point, frontend serves HTTP, backend handles API traffic, database accepts only PostgreSQL connections.
- **`remote_group_id`** is used for inter-tier rules (e.g., SSH from bastion to frontend) instead of CIDR ranges. This is more secure and dynamic — if instances are added to a SG, they automatically gain the correct access.
- **No explicit egress rules** — OpenStack security groups allow all egress by default, and the default egress rules created by Neutron cover IPv4 and IPv6. Adding explicit egress rules would be redundant.
- **HTTP on frontend open to `0.0.0.0/0`** — The OVN load balancer operates at Layer 4 and uses the subnet's IP range. Opening port 80 broadly ensures the LB health checks and traffic forwarding work correctly regardless of the LB's source IP behavior.

## Alternatives

1. **Inline rules within the security group resource** — The `openstack_networking_secgroup_v2` resource supports a `rule` block, but using separate `secgroup_rule_v2` resources is more explicit, easier to maintain, and avoids lifecycle issues when rules change.
2. **CIDR-based rules instead of `remote_group_id`** — Would require hardcoding the subnet CIDR or specific IPs. Less flexible and doesn't adapt to instance changes. Rejected.
3. **Adding explicit egress rules** — The plan mentioned adding egress rules for clarity, but OpenStack creates permissive default egress rules automatically. Adding duplicates would cause conflicts or confusion.
4. **Single security group for all tiers** — Simpler but provides no network isolation. Rejected for security reasons.
