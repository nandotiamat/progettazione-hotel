resource "openstack_networking_floatingip_v2" "debug_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "debug_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.debug_fip.address
  instance_id = openstack_compute_instance_v2.debug_node.id
}
