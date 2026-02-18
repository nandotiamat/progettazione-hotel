variable "external_network_name" {
  type    = string
  default = "public"
}

variable "dns_nameservers" {
  type    = list(string)
  default = ["8.8.8.8", "8.8.4.4"]
}

# --- NETWORK ---

resource "openstack_networking_network_v2" "hotel_net" {
  name           = "hotel-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "hotel_subnet" {
  name            = "hotel-subnet"
  network_id      = openstack_networking_network_v2.hotel_net.id
  cidr            = "10.20.0.0/24" 
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

# --- ROUTER ---

data "openstack_networking_network_v2" "public" {
  name = var.external_network_name
}

resource "openstack_networking_router_v2" "hotel_router" {
  name                = "hotel-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "hotel_router_interface" {
  router_id = openstack_networking_router_v2.hotel_router.id
  subnet_id = openstack_networking_subnet_v2.hotel_subnet.id
}
