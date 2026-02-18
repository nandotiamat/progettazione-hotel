resource "openstack_compute_instance_v2" "test_node" {
  name            = "test-ubuntu-node"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.main_key.name
  
  security_groups = [
    openstack_networking_secgroup_v2.sg_ssh.name,
    openstack_networking_secgroup_v2.sg_internal.name
  ]

  network {
    uuid = openstack_networking_network_v2.main_net.id
  }
}

resource "openstack_compute_instance_v2" "web_node" {
  name            = "web-ubuntu-node"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.main_key.name
  
  security_groups = [
    openstack_networking_secgroup_v2.sg_web.name,
    openstack_networking_secgroup_v2.sg_ssh.name,
    openstack_networking_secgroup_v2.sg_internal.name
  ]

  network {
    uuid = openstack_networking_network_v2.main_net.id
  }

  user_data = file("${path.module}/web-init.yaml")
}
