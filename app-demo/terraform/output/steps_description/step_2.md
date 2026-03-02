## Goal
Add Glance image resources: import Ubuntu Jammy cloud image via URL and reference an existing Cirros image for the bastion.

## Rationale
Using `openstack_images_image_v2` with `image_source_url` lets Glance fetch the Ubuntu cloud image directly without requiring a local file, which fits the constrained DevStack environment. A `data` lookup for Cirros avoids re-importing a default image that DevStack commonly provides.

## Alternatives
- Upload Jammy from a local path (`local_file_path`): rejected because it requires the Terraform runner host to have the image file and increases provisioning friction.
- Import Cirros as a managed resource: rejected because it is typically already present in DevStack and managing it can cause unnecessary drift.
