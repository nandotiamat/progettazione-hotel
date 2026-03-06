# --- Networking Topology (Neutron via OVN) ---

resource "openstack_networking_network_v2" "hotel_private_net" {
  name           = "hotel-private-net"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "hotel_private_subnet" {
  name       = "hotel-private-subnet"
  network_id = openstack_networking_network_v2.hotel_private_net.id
  cidr       = "10.0.1.0/24"
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

data "openstack_networking_network_v2" "external_net" {
  name = var.external_network_name
}

resource "openstack_networking_router_v2" "hotel_router" {
  name                = "hotel-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external_net.id
}

resource "openstack_networking_router_interface_v2" "hotel_router_interface" {
  router_id = openstack_networking_router_v2.hotel_router.id
  subnet_id = openstack_networking_subnet_v2.hotel_private_subnet.id
}
