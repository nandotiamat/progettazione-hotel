## Goal
Provision an Octavia L4 TCP load balancer (OVN provider) with a TCP/80 listener, a pool using `SOURCE_IP_PORT`, a TCP health monitor, and a floating IP associated to the LB VIP.

## Rationale
DevStack is configured for OVN Octavia Provider (no Amphora), so `loadbalancer_provider = "ovn"` is required. Using L4 TCP resources (listener/pool/member/monitor) matches the constraint that OVN LB is handled at the TCP level.

## Alternatives
- Use HTTP listener/monitor: rejected because the requirements specify TCP-only handling and the OVN provider is typically used with L4 semantics.
- Attach the LB floating IP to a member or instance: rejected because the public endpoint must be the LB VIP.
