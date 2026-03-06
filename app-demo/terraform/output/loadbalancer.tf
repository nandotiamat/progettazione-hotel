# --- Load Balancing (Octavia via OVN) ---

resource "openstack_lb_loadbalancer_v2" "hotel_lb" {
  name           = "hotel-lb"
  vip_subnet_id  = openstack_networking_subnet_v2.hotel_private_subnet.id
  admin_state_up = true
  # The requirement strictly mandates ovn provider
  loadbalancer_provider = "ovn"
}

resource "openstack_lb_listener_v2" "hotel_listener" {
  name            = "hotel-listener"
  protocol        = "TCP" # OVN supports only TCP/UDP
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.hotel_lb.id
}

resource "openstack_lb_pool_v2" "hotel_pool" {
  name        = "hotel-pool"
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.hotel_listener.id
}

resource "openstack_lb_member_v2" "hotel_members" {
  count         = 2
  pool_id       = openstack_lb_pool_v2.hotel_pool.id
  address       = openstack_compute_instance_v2.frontend[count.index].network.0.fixed_ip_v4
  protocol_port = 80
}

resource "openstack_lb_monitor_v2" "hotel_monitor" {
  pool_id     = openstack_lb_pool_v2.hotel_pool.id
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

# Floating IPs

resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = data.openstack_networking_network_v2.external_net.name
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.hotel_lb.vip_port_id
}

resource "openstack_networking_floatingip_v2" "bastion_fip" {
  pool = data.openstack_networking_network_v2.external_net.name
}

data "openstack_networking_port_v2" "bastion_port" {
  device_id  = openstack_compute_instance_v2.bastion.id
  network_id = openstack_networking_network_v2.hotel_private_net.id
}

resource "openstack_networking_floatingip_associate_v2" "bastion_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
  port_id     = data.openstack_networking_port_v2.bastion_port.id
}

