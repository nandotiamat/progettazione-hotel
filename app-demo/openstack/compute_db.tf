# --- DB INSTANCE ---

resource "openstack_compute_instance_v2" "db_node" {
  name            = "db-node"
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

    # 1. Early Boot: Write Netplan config to force MTU 1400 BEFORE network starts
    bootcmd:
      - |
        cat <<NETPLAN > /etc/netplan/99-hotel-mtu.yaml
        network:
          version: 2
          ethernets:
            ens3:
              match:
                name: ens3
              mtu: 1400
              dhcp4: true
            eth0:
              match:
                name: eth0
              mtu: 1400
              dhcp4: true
        NETPLAN
      - netplan apply || true

    write_files:
      - path: /opt/install_db.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          set -e
          
          # Fallback: Double-check MTU
          IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
          if [ ! -z "$IFACE" ]; then
            ip link set dev "$IFACE" mtu 1400
          fi
          
          # Install PostgreSQL
          apt-get install -y postgresql postgresql-contrib

          # Configure PostgreSQL to listen on all interfaces
          sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf
          
          # Allow incoming connections from the subnet
          echo "host all all 192.168.1.0/24 md5" >> /etc/postgresql/*/main/pg_hba.conf
          
          # Restart to apply changes
          systemctl restart postgresql

          # Wait for DB to be ready
          sleep 5

          # Setup User and DB
          sudo -u postgres psql -c "CREATE USER dbadmin WITH PASSWORD '${var.db_password}';"
          sudo -u postgres psql -c "CREATE DATABASE myappdb OWNER dbadmin;"
          
          # Apply Schema
          cat <<USERSQL > /tmp/schema.sql
          $(cat ${path.module}/schema.sql)
          USERSQL

          sudo -u postgres psql -d myappdb -f /tmp/schema.sql

    runcmd:
      - [ bash, /opt/install_db.sh ]
  EOF
}
