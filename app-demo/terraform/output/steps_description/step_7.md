# Step 7: compute.tf — Immagine Glance, Flavor, Keypair e Istanze

## Goal

Create all compute resources: upload Ubuntu Jammy cloud image to Glance, look up the pre-existing Cirros image, create a custom flavor (1 vCPU, 2GB RAM, 10GB disk), generate an SSH keypair, and launch 5 Nova instances (2 frontend, 1 backend, 1 database, 1 bastion). Associate the bastion's floating IP for external SSH access.

## Rationale

- **Glance image via `image_source_url`** — Terraform downloads and uploads the Ubuntu cloud image on first apply. Subsequent runs reuse the existing image. This is simpler than pre-uploading manually.
- **Cirros as data source** — The image is already present in DevStack; using `name_regex = "^cirros-.*"` with `most_recent = true` is resilient to version variations.
- **Custom flavor** — DevStack's default flavors may not match our needs. A dedicated `hotel_flavor` (1 vCPU, 2GB, 10GB) provides predictable resource allocation across all 5 VMs.
- **`tls_private_key` + `local_sensitive_file`** — Generates the SSH keypair entirely within Terraform, saving the private key locally with `0600` permissions. No manual key management needed.
- **`count = 2` for frontends** — Simple and sufficient since we have a fixed number of frontend nodes. The `count.index + 1` gives human-friendly names (`hotel-frontend-1`, `hotel-frontend-2`).
- **`templatefile()` for frontend and database** — Injects `node_index` into frontend and DB credentials into the database cloud-init. Backend uses `file()` since it has no variables.
- **`openstack_networking_floatingip_associate_v2`** instead of `openstack_compute_floatingip_associate_v2` — The compute FIP associate resource was removed in provider v3.x. The networking variant uses `port_id` from the instance's network block.

## Alternatives

1. **`for_each` instead of `count` for frontends** — `for_each` is generally preferred for collections, but with exactly 2 identical instances differing only by index, `count` is simpler and clearer.
2. **Pre-uploading the Ubuntu image manually** — Would add a manual step to the workflow. Using `image_source_url` keeps everything declarative in Terraform.
3. **Separate port resources (`openstack_networking_port_v2`)** — Would give more control over IP assignment and security group binding. Unnecessary complexity for this use case; the instance's `network` block handles it.
4. **ED25519 SSH key instead of RSA** — ED25519 is smaller and faster, but Cirros has limited SSH support and RSA 4096 is universally compatible.
