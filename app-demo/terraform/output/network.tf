# output/network.tf
data "openstack_networking_network_v2" "ext_net" {
  name     = "public"
  external = true
}

resource "openstack_networking_router_v2" "router" {
  name                = "app_router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id
}

resource "openstack_networking_network_v2" "app_net" {
  name           = "app_network"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "app_subnet" {
  name       = "app_subnet"
  network_id = openstack_networking_network_v2.app_net.id
  cidr       = "10.0.1.0/24"
  ip_version = 4
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.app_subnet.id
}
