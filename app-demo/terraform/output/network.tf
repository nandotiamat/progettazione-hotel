/* ------------------------------------------------------------------------
   Networking OpenStack: rete interna, subnet, router e connessione esterna.
   Equivalente della VPC AWS con subnet pubbliche/private, IGW e route tables.
   In OpenStack il routing è gestito dal router Neutron anziché da route table
   esplicite. Le subnet "pubbliche" sono collegate al router con gateway esterno,
   mentre le subnet "private" restano isolate (nessuna interfaccia router).
   ------------------------------------------------------------------------ */

# --- RETE ESTERNA (Data Source) ---

# Recuperiamo la rete esterna DevStack ("public") per il gateway del router
data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

# --- RETE INTERNA ---

# Rete interna principale (equivalente della VPC AWS)
resource "openstack_networking_network_v2" "main" {
  name           = "main-network"
  admin_state_up = true
}

# --- SUBNET PUBBLICHE (Per il Load Balancer) ---

resource "openstack_networking_subnet_v2" "public_1" {
  name            = "public-subnet-1"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.1.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_subnet_v2" "public_2" {
  name            = "public-subnet-2"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.2.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

# --- SUBNET PRIVATE (Per Backend e Database) ---

resource "openstack_networking_subnet_v2" "private_1" {
  name            = "private-subnet-1"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.3.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_subnet_v2" "private_2" {
  name            = "private-subnet-2"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.4.0/24"
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

# --- ROUTER (Equivalente dell'Internet Gateway + Route Table pubblica) ---

# Il router connette le subnet pubbliche alla rete esterna DevStack.
# In OpenStack, il router svolge il ruolo combinato di IGW + route table.
resource "openstack_networking_router_v2" "main" {
  name                = "main-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Collegamento delle subnet pubbliche al router
# (equivalente delle aws_route_table_association per le subnet pubbliche)
resource "openstack_networking_router_interface_v2" "public_1" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.public_1.id
}

resource "openstack_networking_router_interface_v2" "public_2" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.public_2.id
}

# Nota: le subnet private NON vengono collegate al router.
# Questo replica il comportamento AWS dove la route table privata
# non ha una rotta verso l'IGW (nessun NAT Gateway configurato).

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
Questo file definisce la topologia di rete OpenStack equivalente alla VPC AWS.

La differenza architetturale principale è che in OpenStack non esiste il concetto
di VPC come contenitore isolato: si crea una "network" (rete L2) e si assegnano
subnet (blocchi IP) a questa rete. L'isolamento è garantito dal fatto che le subnet
condividono lo stesso dominio di broadcast solo se sulla stessa network.

Il router Neutron sostituisce sia l'Internet Gateway che le Route Table di AWS.
Collegando le subnet pubbliche al router (tramite router_interface), queste ottengono
automaticamente una rotta verso la rete esterna. Le subnet private, non collegate,
restano isolate — esattamente come nell'architettura AWS dove la route table privata
non ha rotte verso l'IGW.

La Route53 Private Zone è stata omessa perché DevStack non include Designate (DNS).
La risoluzione interna dei nomi non è disponibile, ma non è critica per un ambiente
di sviluppo locale dove ci si riferisce alle risorse tramite IP.
*/
