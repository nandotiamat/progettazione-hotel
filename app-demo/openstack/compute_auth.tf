# --- AUTH SERVICE (Keycloak) ---

resource "openstack_compute_instance_v2" "auth_node" {
  name            = "auth-node"
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
    
    # Install Docker
    apt-get update
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
  EOF
}
