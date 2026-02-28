/* ------------------------------------------------------------------------
   Security Groups OpenStack (Neutron).
   Sostituisce gli AWS Security Groups con equivalenti Neutron.
   Tre livelli: Load Balancer, Compute, Database.
   ------------------------------------------------------------------------ */

# --- SECURITY GROUP PER IL LOAD BALANCER (Livello Pubblico) ---

resource "openstack_networking_secgroup_v2" "lb_sg" {
  name        = "lb-security-group"
  description = "Permette traffico HTTP/HTTPS pubblico verso il Load Balancer"
}

# Ingress HTTP (porta 80) da ovunque
resource "openstack_networking_secgroup_rule_v2" "lb_ingress_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
}

# Ingress HTTPS (porta 443) da ovunque
resource "openstack_networking_secgroup_rule_v2" "lb_ingress_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
}

# --- SECURITY GROUP PER LE ISTANZE COMPUTE (Livello Applicativo) ---

resource "openstack_networking_secgroup_v2" "compute_sg" {
  name        = "compute-security-group"
  description = "Permette traffico dalle origini autorizzate verso le istanze backend"
}

# Ingress porta 8000 da ovunque (porta applicativa, per debug)
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_app" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8000
  port_range_max    = 8000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
}

# Ingress porta 80 dal Security Group del LB
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_http_from_lb" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = openstack_networking_secgroup_v2.lb_sg.id
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
}

# Ingress SSH (porta 22) dalla rete interna
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
}

# --- SECURITY GROUP PER IL DATABASE (Livello Dati) ---

resource "openstack_networking_secgroup_v2" "db_sg" {
  name        = "db-security-group"
  description = "Permette traffico PostgreSQL solo dalle istanze compute"
}

# Ingress PostgreSQL (porta 5432) solo dal Security Group delle compute
resource "openstack_networking_secgroup_rule_v2" "db_ingress_postgres" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.compute_sg.id
  security_group_id = openstack_networking_secgroup_v2.db_sg.id
}

# --- SECURITY GROUP PER IL BASTION HOST ---

resource "openstack_networking_secgroup_v2" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Permette l'accesso SSH dall'esterno al Bastion Host"
}

# Ingress SSH (porta 22) da Internet
resource "openstack_networking_secgroup_rule_v2" "bastion_ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
}

# --- OUTPUTS ---

output "security_group_lb_id" {
  description = "ID del Security Group del Load Balancer"
  value       = openstack_networking_secgroup_v2.lb_sg.id
}

output "security_group_compute_id" {
  description = "ID del Security Group delle istanze compute"
  value       = openstack_networking_secgroup_v2.compute_sg.id
}

output "security_group_db_id" {
  description = "ID del Security Group del database"
  value       = openstack_networking_secgroup_v2.db_sg.id
}

/*
Questo file replica la struttura a tre livelli di sicurezza del design AWS originale
utilizzando i Security Group di Neutron (openstack_networking_secgroup_v2).

A differenza di AWS, OpenStack crea automaticamente regole di egress che permettono
tutto il traffico in uscita, quindi non è necessario definire regole egress esplicite.
Inoltre, il security group di default in OpenStack include già regole che permettono il
traffico tra membri dello stesso gruppo — per questo definiamo solo le regole di ingresso
specifiche.

La regola remote_group_id è l'equivalente OpenStack del parametro security_groups di AWS:
permette di specificare che il traffico è accettato solo se proviene da un'istanza che
appartiene a un determinato security group, mantenendo la stessa catena di trust
LB -> Compute -> DB del design originale.

Le regole di debug per il VPC di default di LocalStack sono state rimosse poiché non
applicabili all'ambiente OpenStack.
*/
