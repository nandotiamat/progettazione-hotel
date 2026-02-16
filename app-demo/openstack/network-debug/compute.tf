resource "openstack_compute_instance_v2" "debug_node" {
  name            = "debug-node"
  image_name      = var.image_name
  flavor_id       = openstack_compute_flavor_v2.hotel_optimized.id
  config_drive    = true
  security_groups = [openstack_networking_secgroup_v2.sg_debug.name]

  network {
    uuid = openstack_networking_network_v2.debug_net.id
  }

  user_data = <<-EOF
    #cloud-config
    password: password123
    chpasswd: { expire: False }
    ssh_pwauth: True

    # 1. Disable Cloud-Init's automatic network config (which prefers broken DHCP)
    network:
      config: disabled

    # 2. Write a robust Netplan config manually
    write_files:
      - path: /etc/netplan/50-cloud-init.yaml
        permissions: '0600'
        content: |
          network:
            version: 2
            ethernets:
              ens3:
                dhcp4: true
                dhcp4-overrides:
                  use-mtu: false
                  use-dns: false
                mtu: 1400
                nameservers:
                  addresses: [8.8.8.8, 1.1.1.1]

    # 3. Boot Commands: Failsafe measures
    bootcmd:
      # Ensure Loopback is up (critical for systemd-resolved)
      - ip link set lo up
      # Force MTU 1400 immediately on boot
      - ip link set dev ens3 mtu 1400

    # 4. Run Commands: Apply the configuration
    runcmd:
      # Generate and apply the new Netplan config
      - netplan generate
      - netplan apply
      # Restart DNS resolution to pick up 8.8.8.8
      - systemctl restart systemd-resolved
  EOF
}
