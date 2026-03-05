# Step 3: Networking Topology (Neutron via OVN)

## Goal
Provision the underlying private network infrastructure for the environment. This includes creating a dedicated private network, an associated subnet (`10.0.1.0/24`), and a router connecting this subnet to the external network (provider network).

## Rationale
- **Private Subnet**: Providing instances with an explicit private subnet gives them isolated communication lines, mitigating lateral movement risks from external sources.
- **Router with SNAT**: The router provides outbound internet access (via Source NAT). This is crucial because our nodes need to fetch packages (like `nginx`, `fastapi`, `postgres`) during their `cloud-init` bootstrapping phases.

## Alternatives
- **Plugging directly into Provider Net**: This would expose all nodes directly to the provider network. We avoided this to ensure strict segmentation where only specific endpoints (Bastion and LB) have floating IPs and external visibility.
