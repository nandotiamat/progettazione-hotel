resource "openstack_networking_floatingip_v2" "frontend_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name
}

resource "openstack_compute_floatingip_associate_v2" "frontend_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.frontend_fip.address
  instance_id = openstack_compute_instance_v2.frontend[0].id
}

# resource "openstack_networking_floatingip_v2" "backend_fip" {
#   pool = data.openstack_networking_network_v2.ext_net.name
# }

# resource "openstack_compute_floatingip_associate_v2" "backend_fip_assoc" {
#   floating_ip = openstack_networking_floatingip_v2.backend_fip.address
#   instance_id = openstack_compute_instance_v2.backend.id
# }

resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.hotel_lb.vip_port_id
}
