# Step 3: Security Groups (`security.tf`)

## Goal

Create three OpenStack Neutron security groups mirroring the AWS three-tier security model: Load Balancer SG (public HTTP/HTTPS), Compute SG (app port + HTTP from LB + SSH from internal), and Database SG (PostgreSQL from Compute only).

## Rationale

OpenStack's `openstack_networking_secgroup_v2` and `openstack_networking_secgroup_rule_v2` map directly to AWS security groups and rules. The key difference is that OpenStack security groups are not tied to a VPC/network — they exist at the project level and are applied to ports/instances. The `remote_group_id` parameter provides the same inter-group trust chain as AWS's `security_groups` parameter, ensuring the LB → Compute → DB access pattern is enforced.

Egress rules were not explicitly defined because OpenStack's default security group behavior already allows all outbound traffic. This is consistent with the AWS design where egress was set to `0.0.0.0/0` on all protocols.

The LocalStack-specific debug rules (for the default VPC security group) were removed as they have no OpenStack equivalent.

## Alternatives

1. **Using CIDR-based rules instead of remote_group_id** — Would require hardcoding subnet CIDRs. Rejected because `remote_group_id` is more dynamic and precisely mirrors the AWS `security_groups` reference pattern.
2. **Merging LB and Compute security groups** — Since Octavia LBs in OVN provider mode don't always use security groups the same way, merging was considered. Rejected to maintain the architectural clarity and three-tier separation of the original design.
3. **Adding explicit egress rules** — OpenStack allows all egress by default; adding explicit rules would be redundant. Rejected for cleanliness.
