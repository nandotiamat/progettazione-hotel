# Step 6: Compute Instances (Nova)

## Goal
Provision the 5 OpenStack Nova instances: 1 Bastion (Cirros), 1 Database (Ubuntu + DB init), 1 Backend (Ubuntu + FastAPI init), and 2 Frontends (Ubuntu + Nginx init) according to the architecture.

## Rationale
- Each instance binds strictly to its designated tier's Security Group, enforcing the network segmentation policies outlined in Step 2.
- By using `count = 2` for the Frontends, we easily scale horizontally and can dynamically attach them to the Octavia load balancer.
- Using `user_data = file(...)` ensures the `cloud-init` files generated in Step 5 are successfully passed as instance metadata during boot.

## Alternatives
- **Auto Scaling Groups (Senlin)**: For dynamic elasticity, we could have used Senlin or Heat to manage the Frontends, but explicit instance mapping is simpler and sufficient for this specific architectural migration.
