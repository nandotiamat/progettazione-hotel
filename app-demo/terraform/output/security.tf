/* ------------------------------------------------------------------------
   Security Groups e regole di accesso per l'infrastruttura hotel.
   4 gruppi di sicurezza con segmentazione rigorosa tra i livelli:
   bastion, frontend, backend, database.
   ------------------------------------------------------------------------ */

# --- BASTION SECURITY GROUP ---

# SG per il bastion host — accesso SSH dall'esterno
resource "openstack_networking_secgroup_v2" "bastion_sg" {
  name        = "bastion-security-group"
  description = "Security group per il bastion host — SSH da ovunque"
}

# Regola ingress: SSH (porta 22) da qualsiasi indirizzo
resource "openstack_networking_secgroup_rule_v2" "bastion_ssh_ingress" {
  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- FRONTEND SECURITY GROUP ---

# SG per i nodi frontend — HTTP dal LB, SSH dal bastion
resource "openstack_networking_secgroup_v2" "frontend_sg" {
  name        = "frontend-security-group"
  description = "Security group per i nodi frontend — HTTP e SSH dal bastion"
}

# Regola ingress: HTTP (porta 80) da qualsiasi indirizzo (traffico dal Load Balancer)
resource "openstack_networking_secgroup_rule_v2" "frontend_http_ingress" {
  security_group_id = openstack_networking_secgroup_v2.frontend_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

# Regola ingress: SSH (porta 22) dal bastion security group
resource "openstack_networking_secgroup_rule_v2" "frontend_ssh_from_bastion" {
  security_group_id = openstack_networking_secgroup_v2.frontend_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
}

# --- BACKEND SECURITY GROUP ---

# SG per il nodo backend — API REST dai frontend, SSH dai frontend
resource "openstack_networking_secgroup_v2" "backend_sg" {
  name        = "backend-security-group"
  description = "Security group per il nodo backend — HTTP e SSH dai frontend"
}

# Regola ingress: HTTP (porta 80) dal frontend security group
resource "openstack_networking_secgroup_rule_v2" "backend_http_from_frontend" {
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = openstack_networking_secgroup_v2.frontend_sg.id
}

# Regola ingress: SSH (porta 22) dal frontend security group (hop via bastion)
resource "openstack_networking_secgroup_rule_v2" "backend_ssh_from_frontend" {
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.frontend_sg.id
}

# --- DATABASE SECURITY GROUP ---

# SG per il nodo database — PostgreSQL dal backend
resource "openstack_networking_secgroup_v2" "database_sg" {
  name        = "database-security-group"
  description = "Security group per il nodo database — PostgreSQL dal backend"
}

# Regola ingress: PostgreSQL (porta 5432) dal backend security group
resource "openstack_networking_secgroup_rule_v2" "database_postgres_from_backend" {
  security_group_id = openstack_networking_secgroup_v2.database_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.backend_sg.id
}

# --- OUTPUTS ---

output "bastion_sg_id" {
  description = "ID del security group del bastion"
  value       = openstack_networking_secgroup_v2.bastion_sg.id
}

output "frontend_sg_id" {
  description = "ID del security group dei frontend"
  value       = openstack_networking_secgroup_v2.frontend_sg.id
}

output "backend_sg_id" {
  description = "ID del security group del backend"
  value       = openstack_networking_secgroup_v2.backend_sg.id
}

output "database_sg_id" {
  description = "ID del security group del database"
  value       = openstack_networking_secgroup_v2.database_sg.id
}
