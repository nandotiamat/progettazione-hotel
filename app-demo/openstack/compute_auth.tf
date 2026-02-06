# --- AUTH SERVICE (Keycloak) ---

resource "openstack_compute_instance_v2" "auth_node" {
  name            = "auth-node"
  image_name      = var.image_name
  flavor_id       = openstack_compute_flavor_v2.hotel_optimized.id
  key_pair        = var.ssh_key_name
  config_drive    = true
  security_groups = [
    openstack_networking_secgroup_v2.sg_ssh.name,
    openstack_networking_secgroup_v2.sg_internal.name
  ]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: false

    # 1. Early Boot: Force MTU 1400 via Systemd Link
    bootcmd:
      - mkdir -p /etc/systemd/network
      - |
        cat <<EOF > /etc/systemd/network/10-force-mtu.link
        [Match]
        Name=ens*

        [Link]
        MTUBytes=1400
        EOF
      - udevadm control --reload
      - udevadm trigger
      - ip link set dev ens3 mtu 1400 || true
      - systemctl restart systemd-networkd

    write_files:
      - path: /opt/install_auth.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          set -e
          
          # Fallback: Double-check MTU
          IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
          if [ ! -z "$IFACE" ]; then
            ip link set dev "$IFACE" mtu 1400
          fi
          
          # Install Docker
          apt-get install -y docker.io
          systemctl start docker
          systemctl enable docker
          usermod -aG docker ubuntu

          # Run Keycloak
          # Exposed on port 8080 internal
          docker run -d --name keycloak \
            -p 8080:8080 \
            -e KEYCLOAK_ADMIN=admin \
            -e KEYCLOAK_ADMIN_PASSWORD=admin \
            quay.io/keycloak/keycloak:latest \
            start-dev

    runcmd:
      - [ bash, /opt/install_auth.sh ]
  EOF
}
