## Goal
Create the Neutron topology: a single private network/subnet, a router with external gateway, and a router interface so instances have outbound connectivity.

## Rationale
DevStack commonly exposes a pre-existing external network (often named `public`). Attaching `hotel-private-net` to a router with that external gateway is the simplest, most compatible pattern to provide internet egress for apt/pip downloads while keeping instances on a single internal subnet.

## Alternatives
- Use provider networks (flat/vlan) directly for instances: rejected because it bypasses the required private network topology and complicates security segmentation.
- Skip the router and rely on isolated networking: rejected because instances must reach the internet to install packages during cloud-init.
