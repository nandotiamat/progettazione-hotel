data "openstack_compute_flavor_v2" "flavor" {
  name = openstack_compute_flavor_v2.hotel_flavor.name
}

resource "openstack_compute_instance_v2" "backend" {
  count     = var.backend_count
  name      = "${var.app_name}-backend-${count.index}"
  image_id  = openstack_images_image_v2.ubuntu_jammy.id
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = openstack_compute_keypair_v2.hotel_keypair.name


  security_groups = [
    openstack_networking_secgroup_v2.backend.name,
  ]

  network {
    uuid = openstack_networking_network_v2.app_net.id
  }

  user_data = file("${path.module}/user_data/backend.sh")
}

locals {
  backend_fixed_ipv4 = [for i in openstack_compute_instance_v2.backend : i.network[0].fixed_ip_v4]
}

resource "openstack_networking_floatingip_v2" "backend_fip" {
  pool = var.external_network_name
}

data "openstack_networking_port_v2" "backend_port" {
  device_id  = openstack_compute_instance_v2.backend[0].id
  network_id = openstack_networking_network_v2.app_net.id
}

resource "openstack_networking_floatingip_associate_v2" "backend_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.backend_fip.address
  port_id     = data.openstack_networking_port_v2.backend_port.id
}

