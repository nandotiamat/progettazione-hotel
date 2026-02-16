# --- NETWORK ---

resource "openstack_networking_network_v2" "debug_net" {
  name           = "debug-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "debug_subnet" {
  name            = "debug-subnet"
  network_id      = openstack_networking_network_v2.debug_net.id
  cidr            = "192.168.100.0/24"
  ip_version      = 4
  # CRITICAL: NO dns_nameservers set here! Use DevStack defaults.
}

# --- ROUTER ---

data "openstack_networking_network_v2" "public" {
  name = var.external_network_name
}

resource "openstack_networking_router_v2" "debug_router" {
  name                = "debug-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "debug_router_interface" {
  router_id = openstack_networking_router_v2.debug_router.id
  subnet_id = openstack_networking_subnet_v2.debug_subnet.id
}
