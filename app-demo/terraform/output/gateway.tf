# output/gateway.tf
resource "openstack_lb_loadbalancer_v2" "app_lb" {
  name                  = "app_loadbalancer"
  vip_subnet_id         = openstack_networking_subnet_v2.app_subnet.id
  loadbalancer_provider = "ovn"
}

resource "openstack_lb_listener_v2" "app_listener" {
  name            = "app_listener"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.app_lb.id
}

resource "openstack_lb_pool_v2" "app_pool" {
  name        = "app_pool"
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.app_listener.id
}

resource "openstack_lb_member_v2" "app_member" {
  count         = 2
  pool_id       = openstack_lb_pool_v2.app_pool.id
  address       = openstack_compute_instance_v2.app_instance[count.index].access_ip_v4
  protocol_port = 80
}

resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = "public"
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.app_lb.vip_port_id
}
