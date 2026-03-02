data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

resource "openstack_networking_network_v2" "app_net" {
  name           = "${var.app_name}-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "app_subnet" {
  name            = "${var.app_name}-subnet"
  network_id      = openstack_networking_network_v2.app_net.id
  cidr            = var.network_cidr
  ip_version      = 4
  dns_nameservers = var.network_dns_nameservers
}

resource "openstack_networking_router_v2" "app_router" {
  name                = "${var.app_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "app_router_interface" {
  router_id = openstack_networking_router_v2.app_router.id
  subnet_id = openstack_networking_subnet_v2.app_subnet.id
}
