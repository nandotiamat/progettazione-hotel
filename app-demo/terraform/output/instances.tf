locals {
  frontend_count = 2
}

resource "openstack_networking_port_v2" "bastion" {
  name           = "hotel-bastion-port"
  network_id     = openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.bastion.id,
  ]
}

resource "openstack_networking_port_v2" "frontend" {
  count          = local.frontend_count
  name           = "hotel-frontend-${count.index + 1}-port"
  network_id     = openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.frontend.id,
  ]
}

resource "openstack_networking_port_v2" "backend" {
  name           = "hotel-backend-port"
  network_id     = openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.backend.id,
  ]
}

resource "openstack_networking_port_v2" "db" {
  name           = "hotel-db-port"
  network_id     = openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.db.id,
  ]
}

resource "openstack_compute_instance_v2" "bastion" {
  name        = "hotel-bastion"
  image_id    = data.openstack_images_image_v2.cirros.id
  flavor_name = openstack_compute_flavor_v2.hotel_flavor.name
  key_pair    = openstack_compute_keypair_v2.hotel.name

  network {
    port = openstack_networking_port_v2.bastion.id
  }

  depends_on = [openstack_networking_router_interface_v2.private_to_router]
}

resource "openstack_compute_instance_v2" "frontend" {
  count       = local.frontend_count
  name        = "hotel-frontend-${count.index + 1}"
  image_id    = openstack_images_image_v2.ubuntu_jammy.id
  flavor_name = openstack_compute_flavor_v2.hotel_flavor.name
  key_pair    = openstack_compute_keypair_v2.hotel.name

  user_data = templatefile("${path.module}/cloud-init/frontend-init-node.yaml.tftpl", {
    index = count.index + 1
  })

  network {
    port = openstack_networking_port_v2.frontend[count.index].id
  }

  depends_on = [openstack_networking_router_interface_v2.private_to_router]
}

resource "openstack_compute_instance_v2" "backend" {
  name        = "hotel-backend"
  image_id    = openstack_images_image_v2.ubuntu_jammy.id
  flavor_name = openstack_compute_flavor_v2.hotel_flavor.name
  key_pair    = openstack_compute_keypair_v2.hotel.name

  user_data = templatefile("${path.module}/cloud-init/backend-init-node.yaml.tftpl", {})

  network {
    port = openstack_networking_port_v2.backend.id
  }

  depends_on = [openstack_networking_router_interface_v2.private_to_router]
}

resource "openstack_compute_instance_v2" "db" {
  name        = "hotel-db"
  image_id    = openstack_images_image_v2.ubuntu_jammy.id
  flavor_name = openstack_compute_flavor_v2.hotel_flavor.name
  key_pair    = openstack_compute_keypair_v2.hotel.name

  user_data = templatefile("${path.module}/cloud-init/cloud-init-db.yaml.tftpl", {
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = random_password.db_password.result
  })

  network {
    port = openstack_networking_port_v2.db.id
  }

  depends_on = [openstack_networking_router_interface_v2.private_to_router]
}
