resource "openstack_networking_floatingip_v2" "bastion" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "bastion" {
  floating_ip = openstack_networking_floatingip_v2.bastion.address
  port_id     = openstack_networking_port_v2.bastion.id

	depends_on = [
    openstack_networking_router_interface_v2.private_to_router
  ]
}
