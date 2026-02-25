# Step 4: Compute — Load Balancer (`compute.tf`, part 1)

## Goal

Create an Octavia load balancer with an HTTP listener, backend pool, and health monitor — replacing the AWS ALB, target group, listener, and health check configuration.

## Rationale

Octavia with the OVN provider is the load balancing solution available in DevStack. While it operates at L4 (not L7 like AWS ALB), the original AWS configuration only uses a simple forward-all listener on port 80, making L4 sufficient. The `openstack_lb_loadbalancer_v2` is placed on a public subnet to receive external traffic, mirroring the ALB's placement in public subnets.

The pool uses `ROUND_ROBIN` as the load balancing method, which is the closest equivalent to the default ALB distribution. The health monitor uses relaxed thresholds (`expected_codes = "200-499"`, `max_retries = 10`) matching the original LocalStack design where instances may not respond immediately.

The `security_group_ids` parameter on the LB associates it with the LB security group, controlling network access at the VIP level.

## Alternatives

1. **HAProxy on a VM** — Manual load balancer setup. Rejected because Octavia is available in DevStack and provides a managed experience closer to ALB.
2. **Nginx reverse proxy on a compute instance** — More flexible (L7 capable). Rejected because Octavia is the native OpenStack solution and requires less custom configuration.
3. **Using TCP protocol instead of HTTP** — Simpler but loses the ability to do HTTP-level health checks. Rejected to maintain parity with the original health check behavior.
