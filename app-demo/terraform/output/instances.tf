# --- Compute Instances (Nova) ---

resource "openstack_compute_instance_v2" "bastion" {
  name            = "bastion-node"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.bastion_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_private_net.id
  }
}

resource "openstack_compute_instance_v2" "database" {
  name            = "database-node"
  image_id        = openstack_images_image_v2.ubuntu_image.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.database_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_private_net.id
  }

  user_data = file("${path.module}/cloud-init-db.yaml")
}

resource "openstack_compute_instance_v2" "backend" {
  name            = "backend-node"
  image_id        = openstack_images_image_v2.ubuntu_image.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.backend_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_private_net.id
  }

  user_data = file("${path.module}/backend-init-node.yaml")
}

resource "openstack_compute_instance_v2" "frontend" {
  count           = 2
  name            = "frontend-node-${count.index + 1}"
  image_id        = openstack_images_image_v2.ubuntu_image.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.frontend_sg.name]

  network {
    uuid = openstack_networking_network_v2.hotel_private_net.id
  }

  user_data = file("${path.module}/frontend-init-node.yaml")
}
