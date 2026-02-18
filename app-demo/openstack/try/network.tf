# Crea la Rete Privata (L'equivalente della tua VPC)
resource "openstack_networking_network_v2" "private_net" {
  name           = "myapp-private-net"
  admin_state_up = true
}

# Crea la Subnet Privata (Gli indirizzi IP interni)
resource "openstack_networking_subnet_v2" "private_subnet" {
  name       = "myapp-private-subnet"
  network_id = openstack_networking_network_v2.private_net.id
  cidr       = "10.0.1.0/24"
  enable_dhcp = true 
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"] 
}

# Leggi la Rete Pubblica esistente in DevStack
# Nota: Di default DevStack la chiama "public". Se ti dà errore, 
# controlla sulla dashboard Horizon, potrebbe chiamarsi "ext-net".
data "openstack_networking_network_v2" "ext_net" {
  name = "public" 
}

# Crea il Router (L'equivalente dell'Internet Gateway)
resource "openstack_networking_router_v2" "main_router" {
  name                = "myapp-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.ext_net.id
}

#  Collega la tua Subnet Privata al Router
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.main_router.id
  subnet_id = openstack_networking_subnet_v2.private_subnet.id
}
