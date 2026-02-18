resource "openstack_networking_network_v2" "main_net" {
  name = "main-net"
  admin_state_up = "true" 
}

resource "openstack_networking_subnet_v2" "main_subnet" {
  name            = "main-subnet"
  network_id      = openstack_networking_network_v2.main_net.id
  cidr            = var.internal_subnet_cidr
  enable_dhcp 	  = "true"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}
