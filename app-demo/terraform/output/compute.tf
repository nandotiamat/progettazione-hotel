# output/compute.tf

data "openstack_images_image_v2" "cirros" {
  name        = "cirros-0.6.3-x86_64-disk"
  most_recent = true
}

resource "openstack_compute_instance_v2" "app_instance" {
  count           = 2
  name            = "app-instance-${count.index}"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_name     = "m1.nano"
  key_pair        = openstack_compute_keypair_v2.app_key.name
  security_groups = [openstack_networking_secgroup_v2.app_sg.name]

  network {
    uuid = openstack_networking_network_v2.app_net.id
  }
}
