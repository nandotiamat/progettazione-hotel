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

## Failed MTU Configuration Strategies
**Date:** Fri Feb 06 2026
**Description:**
I attempted three different strategies to lower the MTU to 1400 to fix packet fragmentation issues, all of which failed due to a lack of understanding of the specific boot timing and DHCP behaviors in this OpenStack/Ubuntu environment.

1.  **Bootcmd `ip link`:** Failed because I referenced `eth0` while the system renamed the interface to `ens3`. I also failed to account for the persistence of this setting; it was likely overwritten when the network stack fully initialized.
2.  **Systemd Link Unit:** Failed because writing the `.link` file in `bootcmd` was not sufficient to guarantee it was picked up by `udev` before the network interface was initialized by cloud-init/netplan.
3.  **"Nuclear Option" (Static Netplan):** Failed because I used `dhcp4: true` alongside `mtu: 1400` *without* disabling the DHCP client's ability to accept the server-provided MTU. In OpenStack, the DHCP server typically pushes MTU 1500, which overrides the static local setting unless `dhcp4-overrides: { use-mtu: false }` is specified.

**Impact:**
Repeated `terraform apply` cycles with timeouts (`Ign` errors) during `apt-get`, causing significant delay and user frustration.

**Proposed Fix:**
Update the Netplan configuration to explicitly ignore the DHCP-provided MTU:
```yaml
dhcp4-overrides:
  use-mtu: false
```
