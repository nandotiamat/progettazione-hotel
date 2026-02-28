resource "openstack_networking_floatingip_v2" "bastion_fip" {
  pool = data.openstack_networking_network_v2.external.name
}

data "openstack_networking_port_v2" "bastion_port" {
  device_id = openstack_compute_instance_v2.debug_node.id
}

resource "openstack_networking_floatingip_associate_v2" "frontend_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
  port_id     = data.openstack_networking_port_v2.bastion_port.id
}

resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.app_lb.vip_port_id
}
