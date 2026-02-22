resource "openstack_compute_instance_v2" "frontend" {
  count = 2
  name  = "hotel-frontend-${count.index + 1}"

  image_name  = var.image_name
  flavor_name = var.flavor_name

  key_pair = openstack_compute_keypair_v2.hotel_keypair.name

  # IMPORTANTE: In questa risorsa specifica di Terraform per OpenStack, 
  # si usa il NOME del security group, non l'ID!
  security_groups = [openstack_networking_secgroup_v2.frontend_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hotel Management System - Frontend Node ${count.index + 1}" > index.html
              python3 -m http.server 8000 &
              EOF

  depends_on = [
    openstack_networking_subnet_v2.hotel_private_subnet
  ]
}

# --- LA MACCHINA VIRTUALE PER IL DATABASE ---
resource "openstack_compute_instance_v2" "db" {
  name        = "hotel-db"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.hotel_keypair.name

  security_groups = [openstack_networking_secgroup_v2.db_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = file("${path.module}/cloud-init-db.yaml")

  depends_on = [
    openstack_networking_subnet_v2.hotel_private_subnet
  ]
}

# TODO: Eventually, Backend Node will need the DB Node IP, maybe use `templatefile` for instructing the cloud config file.
resource "openstack_compute_instance_v2" "backend" {
  name        = "hotel-backend"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.hotel_keypair.name

  # IMPORTANTE: In questa risorsa specifica di Terraform per OpenStack, 
  security_groups = [openstack_networking_secgroup_v2.backend_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = file("${path.module}/backend-init-node.yaml")

  depends_on = [
    openstack_networking_subnet_v2.hotel_private_subnet
  ]
}
