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
    #cloud-config
    package_update: true
    package_upgrade: false

    # 1. Early Boot: Force MTU 1400 via Systemd Link
    bootcmd:
      - ip link set dev ens3 mtu 1400 || true
      - ip link set dev eth0 mtu 1400 || true
      - systemctl restart systemd-networkd

    write_files:
      - path: /etc/systemd/network/10-force-mtu.link
        content: |
          [Match]
          Name=ens* eth*

          [Link]
          MTUBytes=1400
      - path: /opt/install_app.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          set -e
          
          # Fallback: Double-check MTU
          IFACE=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
          if [ ! -z "$IFACE" ]; then
            ip link set dev "$IFACE" mtu 1400
          fi

          # Install Python & System Dependencies
          apt-get install -y python3 python3-pip python3-venv git

          # Prepare App Directory
          mkdir -p /opt/hotel-backend
          chown ubuntu:ubuntu /opt/hotel-backend
          
          # Create a virtual environment
          python3 -m venv /opt/hotel-backend/venv
          
          # Install common requirements (pre-caching)
          /opt/hotel-backend/venv/bin/pip install fastapi uvicorn sqlalchemy psycopg2-binary boto3 pydantic python-multipart pydantic-settings
          
          # Create a systemd service
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
          Environment="AWS_ACCESS_KEY_ID=test" 
          Environment="AWS_SECRET_ACCESS_KEY=test"
          Environment="AWS_ENDPOINT_URL=http://swift-proxy:8080" 

          [Install]
          WantedBy=multi-user.target
          SERVICE

          systemctl enable hotel-backend
    
    runcmd:
      - [ bash, /opt/install_app.sh ]
  EOF
}
