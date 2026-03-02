## Goal
Create Neutron security groups and rules implementing strict tier segmentation (bastion -> frontend -> backend -> db) using SG-to-SG rules where required.

## Rationale
Using `remote_group_id` for the SSH and DB rules enforces "strictly from SG" semantics even if instance IPs change. Keeping HTTP/80 open for frontend and backend follows the requirements and simplifies connectivity during initial bring-up.

## Alternatives
- Use CIDR-based rules for internal access: rejected because it does not satisfy the requirement to allow access strictly from another security group.
- Restrict backend HTTP to frontend SG only: not chosen because the requirements explicitly say allow TCP/80 and only constrain SSH from frontend SG.
