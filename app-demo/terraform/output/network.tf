data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

resource "openstack_networking_network_v2" "private" {
  name           = "hotel-private-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "private" {
  name            = "hotel-private-subnet"
  network_id      = openstack_networking_network_v2.private.id
  cidr            = "10.0.1.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "router" {
  name                = "hotel-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "private_to_router" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.private.id
}
