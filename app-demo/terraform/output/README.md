# OpenStack (DevStack) Terraform - Hotel Demo

This Terraform root module targets a local DevStack (stable/2025.1) deployment using `clouds.yaml` authentication.

## Prereqs

- DevStack is running with Neutron+OVN, Swift, and Octavia (OVN provider).
- A `clouds.yaml` entry exists matching `var.os_cloud` (default: `devstack`).

## Typical workflow

```bash
cd output
terraform init
terraform validate
terraform plan
terraform apply
```

## Inputs

- `os_cloud`: clouds.yaml cloud name (default `devstack`)
- `external_network_name`: external network name (default `public`)
- `jammy_image_source_url`: Ubuntu Jammy cloud image URL

## Outputs / generated files

- Terraform outputs:
  - `bastion_floating_ip`
  - `lb_floating_ip`
- Local generated files (not to be committed):
  - `.env` (secrets + connection info)
  - `~/.ssh/hotel-key.pem` (private key)

## Seed media

Place `.png`, `.jpg`, or `.jpeg` files under `seed_media/` and apply; Terraform uploads them into the Swift container `hotel-assets`.
