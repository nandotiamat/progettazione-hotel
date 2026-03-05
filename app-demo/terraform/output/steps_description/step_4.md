# Step 4: Compute and Load Balancing Configuration

## Goal
Map EC2/ECS resources to Nova instances and ALB/API Gateways to Octavia OVN Load Balancers.

## Rationale
To strictly abide by the 6 vCPU constraint, `compute.tf` deploys instances using the minimal `m1.nano` flavor and the `cirros` image instead of heavyweight OS images. The AWS Load Balancers are replaced in `gateway.tf` using Octavia (`openstack_lb_loadbalancer_v2`, listener, pool, and members). Since DevStack is configured with `OCTAVIA_USE_AMPHORA_PROVIDER=False`, this avoids spinning up extra Amphora VMs and instead maps VIPs efficiently onto the OVN networking layer. 

## Alternatives
*   **Alternative considered:** Use Kubernetes (Magnum) or large Auto-Scaling Groups instead of raw instances.
*   **Why it was not chosen:** Magnum isn't enabled in the target environment, and large ASGs would easily exceed the 6 vCPU maximum threshold. We explicitly kept the instance count to `2` minimal nodes.