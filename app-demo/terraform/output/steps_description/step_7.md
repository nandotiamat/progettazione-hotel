# Step 7: Load Balancing (Octavia via OVN)

## Goal
Provision a Layer 4 (TCP) Load Balancer using Octavia configured strictly with the `ovn` provider to distribute incoming traffic across the two frontend instances, and associate a Floating IP to expose it externally.

## Rationale
- **OVN Provider Restriction**: The requirements explicitly mandated using the `loadbalancer_provider = "ovn"` setting. OVN in Octavia lacks Layer 7 (HTTP) features. Therefore, the listener, pool, and monitor are all configured exclusively for `TCP`.
- **`SOURCE_IP_PORT` Algorithm**: This algorithm ensures deterministic connection stickiness at the OVN router level, preventing session disruption without relying on Layer 7 cookies.
- **Floating IP Management**: We use `openstack_networking_floatingip_associate_v2` to map the public IP strictly to the Load Balancer VIP port and the Bastion port, cleanly decoupling network routing from instance state.

## Alternatives
- **Amphora Provider**: Using Octavia's default `amphora` provider would have allowed for HTTP listener types and Layer 7 policies, but this directly contradicted the prompt's explicit requirement to utilize OVN.
