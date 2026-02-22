# Crea la Rete Privata (L'equivalente della tua VPC)
resource "openstack_networking_network_v2" "hotel_net" {
  name           = "hotel-private-net"
  admin_state_up = true
}

# Crea la Subnet Privata (Gli indirizzi IP interni)
resource "openstack_networking_subnet_v2" "hotel_private_subnet" {
  name            = "hotel-private-subnet"
  network_id      = openstack_networking_network_v2.hotel_net.id
  cidr            = var.internal_subnet_cidr
  enable_dhcp     = true
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Leggi la Rete Pubblica esistente in DevStack
# It should be safe to read with data since DevStack always creates a public network named `public`
data "openstack_networking_network_v2" "ext_net" {
  name = "public"
}

# Crea il Router (L'equivalente dell'Internet Gateway)
resource "openstack_networking_router_v2" "hotel_router" {
  name                = "hotel-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id
}

#  Collega la tua Subnet Privata al Router
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.hotel_router.id
  subnet_id = openstack_networking_subnet_v2.hotel_private_subnet.id
}
