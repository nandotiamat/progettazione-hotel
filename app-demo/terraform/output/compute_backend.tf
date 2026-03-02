data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}

resource "openstack_compute_instance_v2" "backend" {
  count     = var.backend_count
  name      = "${var.app_name}-backend-${count.index}"
  image_id  = data.openstack_images_image_v2.image.id
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = var.keypair_name

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
