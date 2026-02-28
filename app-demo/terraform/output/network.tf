/* ------------------------------------------------------------------------
   Networking OpenStack (Neutron + OVN).
   Sostituisce VPC, subnet, IGW e route table di AWS.
   Il router OpenStack funge sia da Internet Gateway che da route table.
   ------------------------------------------------------------------------ */

# --- RETE ESTERNA (DevStack) ---

# Riferimento alla rete esterna "public" già presente in DevStack
data "openstack_networking_network_v2" "external" {
  name = "public"
}

# --- RETE INTERNA ---

# Rete interna principale (equivalente di aws_vpc)
resource "openstack_networking_network_v2" "main" {
  name           = "myapp-network"
  admin_state_up = true
}

# --- SUBNET PUBBLICHE (Per Load Balancer) ---

resource "openstack_networking_subnet_v2" "public_1" {
  name            = "public-subnet-1"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.1.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_subnet_v2" "public_2" {
  name            = "public-subnet-2"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.2.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# --- SUBNET PRIVATE (Per Compute e DB) ---

resource "openstack_networking_subnet_v2" "private_1" {
  name            = "private-subnet-1"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.3.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_subnet_v2" "private_2" {
  name            = "private-subnet-2"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.4.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# --- ROUTER (Equivalente di Internet Gateway + Route Table) ---

# Il router connette le subnet interne alla rete esterna
resource "openstack_networking_router_v2" "main" {
  name                = "myapp-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Collegamento delle subnet pubbliche al router
# (equivalente di aws_route_table_association per le subnet pubbliche)
resource "openstack_networking_router_interface_v2" "public_1" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.public_1.id
}

resource "openstack_networking_router_interface_v2" "public_2" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.public_2.id
}

resource "openstack_networking_router_interface_v2" "private_1" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.private_1.id
}

resource "openstack_networking_router_interface_v2" "private_2" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.private_2.id
}

# Le subnet private NON sono collegate al router (isolate, come nel design AWS senza NAT)

# Le subnet private NON sono collegate al router (isolate, come nel design AWS senza NAT)

# --- OUTPUTS ---

output "network_id" {
  description = "ID della rete interna principale"
  value       = openstack_networking_network_v2.main.id
}

output "public_subnet_ids" {
  description = "Lista degli ID delle subnet pubbliche"
  value       = [openstack_networking_subnet_v2.public_1.id, openstack_networking_subnet_v2.public_2.id]
}

output "private_subnet_ids" {
  description = "Lista degli ID delle subnet private"
  value       = [openstack_networking_subnet_v2.private_1.id, openstack_networking_subnet_v2.private_2.id]
}

output "router_id" {
  description = "ID del router principale"
  value       = openstack_networking_router_v2.main.id
}

/*
Questo file definisce la topologia di rete OpenStack, equivalente alla VPC AWS.

In OpenStack non esiste il concetto di VPC: la rete interna (openstack_networking_network_v2)
funge da contenitore logico isolato. Le subnet vengono create sulla stessa rete ma con CIDR
distinti, mantenendo la stessa struttura a 4 subnet del design AWS originale.

Il router OpenStack (openstack_networking_router_v2) sostituisce sia l'Internet Gateway che
le Route Table di AWS. Collegando il router alla rete esterna "public" di DevStack e
attaccando le subnet pubbliche tramite router_interface, otteniamo lo stesso effetto della
route table pubblica con rotta 0.0.0.0/0 verso l'IGW.

Le subnet private rimangono deliberatamente scollegate dal router, replicando il comportamento
AWS dove non c'era un NAT Gateway: le risorse nelle subnet private non hanno accesso diretto
a internet.

La Route53 private zone è stata rimossa poiché DevStack non ha Designate abilitato.
*/
