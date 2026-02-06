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
    package_update: false
    package_upgrade: false

    bootcmd:
      - [ sh, -c, "for dev in $(ls /sys/class/net/ | grep -v lo); do ip link set dev $dev mtu 1400; done" ]

    write_files:
      - path: /opt/install_db.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          set -e
          
          # Install PostgreSQL
          apt-get update
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
