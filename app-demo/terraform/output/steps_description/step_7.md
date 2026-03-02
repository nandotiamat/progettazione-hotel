## Goal
Provision the required instances (2x frontend, 1x backend, 1x DB, 1x bastion) on the private network, attach the correct security groups via explicit Neutron ports, and allocate/associate a floating IP only for the bastion.

## Rationale
Explicit ports make security-group attachment unambiguous and allow later reuse of fixed IPs (for Octavia pool membership). Only the bastion receives a floating IP, matching the requirement that internal nodes stay private and are accessed via SSH jump.

## Alternatives
- Attach security groups directly on instances without ports: rejected because it makes SG composition and later LB member referencing less explicit.
- Give floating IPs to frontends for debugging: rejected because it violates the requirement that only bastion and LB VIP get public IPs.
