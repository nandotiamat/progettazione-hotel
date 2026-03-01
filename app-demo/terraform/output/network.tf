/* ------------------------------------------------------------------------
   Rete, subnet, router e floating IPs per l'infrastruttura hotel.
   Crea una rete privata con subnet, collegata alla rete esterna DevStack
   tramite un router. Alloca floating IPs per bastion e load balancer.
   ------------------------------------------------------------------------ */

# --- DATA SOURCE: RETE ESTERNA ---

# Recupera la rete esterna DevStack (tipicamente "public")
data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

# --- RETE PRIVATA ---

# Rete interna per tutte le istanze dell'applicazione hotel
resource "openstack_networking_network_v2" "hotel_net" {
  name           = "hotel-private-net"
  admin_state_up = true
}

# Subnet privata con DHCP abilitato e DNS configurato
resource "openstack_networking_subnet_v2" "hotel_subnet" {
  name            = "hotel-private-subnet"
  network_id      = openstack_networking_network_v2.hotel_net.id
  cidr            = var.private_network_cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers
}

# --- ROUTER ---

# Router che collega la rete privata alla rete esterna per l'accesso internet
resource "openstack_networking_router_v2" "hotel_router" {
  name                = "hotel-router"
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Interfaccia che collega il router alla subnet privata
resource "openstack_networking_router_interface_v2" "router_iface" {
  router_id = openstack_networking_router_v2.hotel_router.id
  subnet_id = openstack_networking_subnet_v2.hotel_subnet.id
}

# --- FLOATING IPs ---

# Floating IP per il bastion host (accesso SSH dall'esterno)
resource "openstack_networking_floatingip_v2" "bastion_fip" {
  pool = var.external_network_name
}

# Floating IP per il load balancer (accesso HTTP dall'esterno)
resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = var.external_network_name
}

# --- OUTPUTS ---

output "network_id" {
  description = "ID della rete privata hotel"
  value       = openstack_networking_network_v2.hotel_net.id
}

output "subnet_id" {
  description = "ID della subnet privata hotel"
  value       = openstack_networking_subnet_v2.hotel_subnet.id
}

output "router_id" {
  description = "ID del router hotel"
  value       = openstack_networking_router_v2.hotel_router.id
}

output "bastion_floating_ip" {
  description = "Indirizzo floating IP del bastion host"
  value       = openstack_networking_floatingip_v2.bastion_fip.address
}

output "lb_floating_ip" {
  description = "Indirizzo floating IP del load balancer"
  value       = openstack_networking_floatingip_v2.lb_fip.address
}
