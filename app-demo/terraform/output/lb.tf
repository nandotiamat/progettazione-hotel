resource "openstack_lb_loadbalancer_v2" "hotel" {
  name                  = "hotel-lb"
  vip_subnet_id         = openstack_networking_subnet_v2.private.id
  loadbalancer_provider = "ovn"

  depends_on = [openstack_networking_router_interface_v2.private_to_router]
}

resource "openstack_lb_listener_v2" "http" {
  name            = "hotel-lb-listener-80"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.hotel.id
}

resource "openstack_lb_pool_v2" "frontend" {
  name        = "hotel-frontend-pool"
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.http.id
}

resource "openstack_lb_member_v2" "frontend" {
  count         = local.frontend_count
  pool_id       = openstack_lb_pool_v2.frontend.id
  address       = openstack_networking_port_v2.frontend[count.index].all_fixed_ips[0]
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.private.id
}

resource "openstack_lb_monitor_v2" "tcp" {
  pool_id     = openstack_lb_pool_v2.frontend.id
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

resource "openstack_networking_floatingip_v2" "lb" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_lb_loadbalancer_v2.hotel.vip_port_id
}
