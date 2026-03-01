# Step 8: loadbalancer.tf — Octavia Load Balancer (OVN Provider)

## Goal

Create an Octavia load balancer with the OVN provider operating at Layer 4 (TCP). The LB listens on port 80, distributes traffic across the two frontend instances via a pool with TCP health monitoring, and is exposed externally via a floating IP associated to its VIP port.

## Rationale

- **`loadbalancer_provider = "ovn"`** — The DevStack `local.conf` disables Amphora (`OCTAVIA_USE_AMPHORA_PROVIDER=False`), so the OVN native provider must be used explicitly. This provides a lightweight Layer 4 LB without the overhead of spawning Amphora VMs.
- **TCP protocol for everything** — OVN load balancers operate at Layer 4 only. The listener, pool, and health monitor all use TCP. HTTP-level features (path routing, header inspection) are not available.
- **`SOURCE_IP_PORT` algorithm** — Provides good traffic distribution by hashing both source IP and port. This is supported by the OVN provider in recent versions. The plan noted `SOURCE_IP` as a fallback if this doesn't work at apply time.
- **Individual member resources** — Two separate `openstack_lb_member_v2` resources (one per frontend) instead of a `count`/`for_each` loop. This is explicit and avoids potential ordering issues with the pool.
- **FIP via `vip_port_id`** — The `openstack_networking_floatingip_associate_v2` binds the floating IP to the LB's VIP port, making the LB accessible from outside the private network.

## Alternatives

1. **Amphora provider** — Would provide Layer 7 (HTTP) load balancing but is disabled in this DevStack configuration. Not an option.
2. **`count` or `for_each` for members** — Would reduce code duplication for 2 members, but with only 2 static members the explicit approach is clearer and avoids index/key complexity.
3. **HTTP health monitor** — Would check actual HTTP responses (e.g., 200 OK) but requires the `HTTP` protocol which OVN doesn't support. TCP health checks are sufficient for availability monitoring.
4. **`ROUND_ROBIN` algorithm** — Simpler but less deterministic for session affinity. `SOURCE_IP_PORT` provides better distribution and natural session stickiness.
