# Step 2: Networking (`network.tf`)

## Goal

Translate the AWS VPC, subnets, Internet Gateway, and route tables into OpenStack Neutron equivalents: an internal network, four subnets (2 public, 2 private), a router connected to DevStack's external `public` network, and router interface attachments for the public subnets.

## Rationale

OpenStack's networking model differs fundamentally from AWS. There is no VPC construct — instead, `openstack_networking_network_v2` creates an isolated L2 network. Subnets are attached to this network with distinct CIDRs matching the original AWS design (10.0.1.0/24 through 10.0.4.0/24). The router replaces both the AWS Internet Gateway and public route table in a single resource: by setting `external_network_id` to the DevStack `public` network, the router provides external connectivity; by attaching subnet interfaces, it handles routing.

Private subnets are deliberately left unattached to the router, mirroring the original AWS design where no NAT Gateway was configured — private resources have no internet access.

Route53 private DNS zone was dropped entirely since DevStack does not have Designate enabled.

## Alternatives

1. **Separate networks per subnet** — Creating individual `openstack_networking_network_v2` resources for each subnet. Rejected because it adds unnecessary complexity; a single network with multiple subnets is the standard OpenStack pattern and closer to the AWS VPC model.
2. **Attaching private subnets to the router** — Would give private instances internet access. Rejected to maintain architectural parity with the AWS design (no NAT).
3. **Using availability zone hints** — OpenStack supports AZ hints on networks/subnets, but DevStack typically has a single AZ, making this unnecessary. Rejected for simplicity.
