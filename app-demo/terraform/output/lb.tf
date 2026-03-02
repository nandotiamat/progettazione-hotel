resource "openstack_lb_loadbalancer_v2" "app" {
  name          = "${var.app_name}-lb"
  vip_subnet_id = openstack_networking_subnet_v2.app_subnet.id
}

resource "openstack_lb_listener_v2" "http" {
  name            = "${var.app_name}-http"
  protocol        = "HTTP"
  protocol_port   = var.lb_listen_port
  loadbalancer_id = openstack_lb_loadbalancer_v2.app.id
}

resource "openstack_lb_pool_v2" "backend" {
  name        = "${var.app_name}-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.http.id
}

resource "openstack_lb_monitor_v2" "http" {
  pool_id     = openstack_lb_pool_v2.backend.id
  type        = "HTTP"
  delay       = 5
  timeout     = 3
  max_retries = 3
  url_path    = "/health"
}

resource "openstack_lb_member_v2" "backend" {
  count         = var.backend_count
  pool_id       = openstack_lb_pool_v2.backend.id
  address       = local.backend_fixed_ipv4[count.index]
  protocol_port = var.backend_app_port
  subnet_id     = openstack_networking_subnet_v2.app_subnet.id
}

resource "openstack_networking_floatingip_v2" "lb" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "lb" {
  floating_ip = openstack_networking_floatingip_v2.lb.address
  port_id     = openstack_lb_loadbalancer_v2.app.vip_port_id
}
