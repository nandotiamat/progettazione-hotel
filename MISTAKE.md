# Mistakes Log

## Missing SSH Private Key Output
**Date:** Fri Feb 06 2026
**Description:**
I instructed the user to SSH into the VMs (`ssh -i ... ubuntu@<ip>`) to verify the setup, but I failed to configure Terraform to output or save the generated SSH private key. The `openstack_compute_keypair_v2` resource generates a key pair, but without a corresponding `output` or `local_file` resource, the private key is lost in the state file and not easily accessible to the user on the host machine.

**Impact:**
User could not verify the infrastructure as requested.

**Fix:**
1.  Added a `local_file` resource in `keypair.tf` to save the private key to `hotel-key.pem` with `0600` permissions.
2.  Added a sensitive output in `outputs.tf` for the private key.
