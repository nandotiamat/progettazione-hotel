output "debug_node_ip" {
  value = openstack_compute_instance_v2.debug_node.access_ip_v4
}

output "debug_node_fip" {
  value = openstack_networking_floatingip_v2.debug_fip.address
}
