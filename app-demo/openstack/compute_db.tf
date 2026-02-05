# --- DB INSTANCE ---

resource "openstack_compute_instance_v2" "db_node" {
  name            = "db-node"
  image_name      = var.image_name
  flavor_id       = openstack_compute_flavor_v2.hotel_optimized.id
  key_pair        = var.ssh_key_name
  security_groups = [
    openstack_networking_secgroup_v2.sg_ssh.name,
    openstack_networking_secgroup_v2.sg_internal.name
  ]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = <<-EOF
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
    # We write the schema file from Terraform to the instance using a cloud-init write_files equivalent or just echo here
    # For simplicity, since we have the file in the repo, we can't easily "upload" it via user_data without encoding it.
    # A robust way is to use 'provisioner "file"' but that requires SSH connectivity.
    # Here we will try to embed the schema.sql content directly into the script.
    
    cat <<USERSQL > /tmp/schema.sql
    $(cat ${path.module}/schema.sql)
    USERSQL

    sudo -u postgres psql -d myappdb -f /tmp/schema.sql
  EOF
}
