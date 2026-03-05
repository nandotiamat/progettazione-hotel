# Step 2: Network and Security Configuration

## Goal
Map AWS VPC, subnets, IGW, and Security Groups to OpenStack Neutron constructs.

## Rationale
To ensure compatibility with DevStack's OVN configuration, `network.tf` defines an OpenStack router, a network with MTU strictly set to 1450 (due to nested virtualization), and a subnet. `security.tf` implements Neutron security groups and rules for basic ingress to replace AWS Security Groups.

## Alternatives
*   **Alternative considered:** Use pre-existing DevStack networks instead of provisioning new ones.
*   **Why it was not chosen:** Creating dedicated tenant networks is closer to the original AWS architecture (using distinct VPCs) and tests the provisioning of isolated network segments.