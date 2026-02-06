# Plan: Fixing DHCP MTU Override

## The Problem
Despite implementing the "Nuclear Option" (disabling cloud-init networking and enforcing a static Netplan configuration), the VMs are still experiencing packet fragmentation issues. This manifests as `Ign` (ignore) and timeout errors during `apt-get update`, indicating that the repositories are unreachable due to dropped packets larger than the VXLAN tunnel capacity.

## Root Cause Analysis
OpenStack's DHCP server typically provides an MTU option (usually 1500) along with the IP address. By default, the Netplan DHCP client accepts this option, overwriting any locally configured `mtu` setting.

In our previous attempt:
```yaml
ethernets:
  ens3:
    dhcp4: true
    mtu: 1400  <-- This is being ignored/overridden by DHCP
```

## The Solution
We must explicitly instruct the DHCP client **not** to accept the MTU provided by the server. This is done using the `dhcp4-overrides` directive in Netplan.

## Implementation Steps

We will update the `write_files` section in the following 4 files:
1.  `app-demo/openstack/nginx_setup.sh.tpl`
2.  `app-demo/openstack/compute_app.tf`
3.  `app-demo/openstack/compute_db.tf`
4.  `app-demo/openstack/compute_auth.tf`

### New Netplan Configuration
The content of `/etc/netplan/01-netcfg.yaml` will be updated to:

```yaml
network:
  version: 2
  ethernets:
    ens3:
      match:
        name: ens3
      dhcp4: true
      dhcp4-overrides:       # <--- NEW: Prevent DHCP from changing MTU
        use-mtu: false
      mtu: 1400              # <--- This will now be respected
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```

## Verification Strategy
1.  **Deploy:** Run `terraform apply`.
2.  **Check IP:** Verify the interface has MTU 1400 via `ip link show ens3`.
3.  **Check Connectivity:** Success is defined by `apt-get update` completing without `Ign` or timeout errors in the cloud-init logs.
