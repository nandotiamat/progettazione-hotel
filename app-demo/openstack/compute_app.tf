# --- APP INSTANCES ---

resource "openstack_compute_instance_v2" "app_node" {
  count           = 2
  name            = "app-node-${count.index + 1}"
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

  # Dependency on DB
  depends_on = [openstack_compute_instance_v2.db_node]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Fix MTU for Nested Virtualization
    ip link set dev eth0 mtu 1400 || ip link set dev ens3 mtu 1400

    # Install Python & System Dependencies
    apt-get update
    apt-get install -y python3 python3-pip python3-venv git

    # Prepare App Directory
    mkdir -p /opt/hotel-backend
    chown ubuntu:ubuntu /opt/hotel-backend
    
    # We will upload the code via provisioner or assume it's delivered via CI/CD
    # For now, let's just ensure the environment is ready.
    
    # Create a virtual environment
    python3 -m venv /opt/hotel-backend/venv
    
    # Install common requirements (pre-caching)
    /opt/hotel-backend/venv/bin/pip install fastapi uvicorn sqlalchemy psycopg2-binary boto3 pydantic python-multipart pydantic-settings
    
    # Create a systemd service (it will fail until code is there, but structure is ready)
    cat <<SERVICE > /etc/systemd/system/hotel-backend.service
    [Unit]
    Description=Hotel Backend API
    After=network.target

    [Service]
    User=ubuntu
    WorkingDirectory=/opt/hotel-backend
    ExecStart=/opt/hotel-backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
    Restart=always
    Environment="DB_HOST=${openstack_compute_instance_v2.db_node.access_ip_v4}"
    Environment="DB_USER=dbadmin"
    Environment="DB_PASS=${var.db_password}"
    Environment="DB_NAME=myappdb"
    # AWS/S3 Config for Swift (using S3 compat or just pretending)
    # OpenStack Swift S3 API usually at port 8080
    Environment="AWS_ACCESS_KEY_ID=test" 
    Environment="AWS_SECRET_ACCESS_KEY=test"
    Environment="AWS_ENDPOINT_URL=http://swift-proxy:8080" 

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl enable hotel-backend
  EOF
}
