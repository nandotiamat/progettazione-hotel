# Step 5: Compute — Instances (`compute.tf`, part 2)

## Goal

Replace the AWS Auto Scaling Group, Launch Template, and CloudWatch alarm with fixed-count Nova compute instances, register them as Octavia pool members, and create a debug instance — completing the compute layer.

## Rationale

OpenStack does not have a native Auto Scaling Group equivalent (Heat autoscaling exists but requires Heat/Ceilometer/Aodh, none of which are in this DevStack). Using `count = 2` on `openstack_compute_instance_v2` simulates the ASG's `desired_capacity = 2`. Instances are distributed across private subnets using `count.index % 2` with `cidrhost()` for deterministic IP assignment.

Each instance is registered as an `openstack_lb_member_v2` in the Octavia pool, replacing the ASG's automatic target group registration. Data sources (`openstack_images_image_v2` and `openstack_compute_flavor_v2`) look up the image and flavor by name, keeping the configuration flexible via variables.

CloudWatch alarms and scaling policies were skipped entirely as noted in the plan — DevStack lacks monitoring/alarming services.

## Alternatives

1. **Heat autoscaling stack** — Full ASG equivalent using Heat templates. Rejected because Heat is not available in this DevStack configuration and adds significant complexity.
2. **Using `for_each` with a map** — More explicit than `count` for named instances. Rejected because `count` is simpler for identical instances and the plan specifically mentions `count`.
3. **Floating IPs for backend instances** — Would give direct external access. Rejected because backend instances should remain in private subnets, accessible only through the load balancer, matching the original AWS design.
4. **Skipping the debug instance** — Considered since it was LocalStack-specific. Included because it provides useful debugging capability in the DevStack environment as well.
