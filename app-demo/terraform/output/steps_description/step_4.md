# Step 4: Images & Flavors (Glance & Nova)

## Goal
To define the base computing assets necessary for running instances in Nova. This includes dynamically downloading and registering an Ubuntu Jammy image with Glance, locating the default Cirros image for a lightweight Bastion, and defining the target `hotel_flavor` (1vCPU, 2GB RAM, 10GB disk).

## Rationale
- **Automated Image Uploads**: Directly downloading the Ubuntu `.img` dynamically in Terraform ensures consistency across environment recreations and eliminates manual setup steps. The `openstack_images_image_v2` is perfect for automatically downloading from an internet URL.
- **`cirros` for Bastion**: The Bastion acts strictly as an SSH jump host. Using a minimal footprint OS like `cirros` keeps the environment lean instead of provisioning a full Ubuntu server for it.
- **Custom Flavor**: We define `hotel_flavor` matching the constraints in the prompt (1/2048/10), which is often slightly larger than the DevStack default `m1.tiny` but smaller than `m1.small`, optimizing for nested environments.

## Alternatives
- **Packer-built Immutable Images**: We could pre-bake the images and reference them here. While more robust, this conflicts with the immediate goal of deploying `cloud-init` directly through Terraform for dynamic application initialization.
