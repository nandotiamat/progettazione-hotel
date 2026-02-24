/* ------------------------------------------------------------------------
   Security Groups OpenStack (Neutron).
   Equivalente dei Security Groups AWS per LB, Compute e Database.
   In OpenStack le regole sono risorse separate (secgroup_rule) anziché
   blocchi inline come in AWS. L'egress è permesso di default in OpenStack,
   ma lo rendiamo esplicito per chiarezza e parità col design originale.
   ------------------------------------------------------------------------ */

# --- SECURITY GROUP PER IL LOAD BALANCER (Livello Pubblico) ---

resource "openstack_networking_secgroup_v2" "lb_sg" {
  name                 = "lb-security-group"
  description          = "Permette traffico HTTP/HTTPS pubblico verso il Load Balancer"
  delete_default_rules = true # Rimuoviamo le regole di default per controllo esplicito
}

# Ingresso HTTP (porta 80) da ovunque
resource "openstack_networking_secgroup_rule_v2" "lb_ingress_http" {
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

# Ingresso HTTPS (porta 443) da ovunque
resource "openstack_networking_secgroup_rule_v2" "lb_ingress_https" {
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

# Uscita: il LB deve poter comunicare con le istanze backend
resource "openstack_networking_secgroup_rule_v2" "lb_egress_all" {
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- SECURITY GROUP PER LE ISTANZE COMPUTE (Livello Applicativo) ---

resource "openstack_networking_secgroup_v2" "compute_sg" {
  name                 = "compute-security-group"
  description          = "Permette traffico dal Load Balancer e SSH interno"
  delete_default_rules = true
}

# Ingresso sulla porta applicativa (8000) da ovunque (per debug)
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_app" {
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.app_port
  port_range_max    = var.app_port
  remote_ip_prefix  = "0.0.0.0/0"
}

# Ingresso HTTP (porta 80) solo dal Security Group del LB
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_http_from_lb" {
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = openstack_networking_secgroup_v2.lb_sg.id
}

# Ingresso SSH (porta 22) solo dalla rete interna
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_ssh" {
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "10.0.0.0/16"
}

# Uscita: le istanze devono poter scaricare pacchetti, contattare Swift, DB, etc.
resource "openstack_networking_secgroup_rule_v2" "compute_egress_all" {
  security_group_id = openstack_networking_secgroup_v2.compute_sg.id
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- SECURITY GROUP PER IL DATABASE (Livello Dati) ---

resource "openstack_networking_secgroup_v2" "db_sg" {
  name                 = "db-security-group"
  description          = "Permette traffico PostgreSQL solo dalle istanze compute"
  delete_default_rules = true
}

# Ingresso PostgreSQL (porta 5432) solo dal Security Group delle istanze compute
resource "openstack_networking_secgroup_rule_v2" "db_ingress_postgres" {
  security_group_id = openstack_networking_secgroup_v2.db_sg.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.compute_sg.id
}

# Uscita minima per il DB (risposte alle query)
resource "openstack_networking_secgroup_rule_v2" "db_egress_all" {
  security_group_id = openstack_networking_secgroup_v2.db_sg.id
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- OUTPUTS ---

output "security_group_lb_id" {
  description = "ID del Security Group del Load Balancer"
  value       = openstack_networking_secgroup_v2.lb_sg.id
}

output "security_group_compute_id" {
  description = "ID del Security Group delle istanze Compute"
  value       = openstack_networking_secgroup_v2.compute_sg.id
}

output "security_group_db_id" {
  description = "ID del Security Group del Database"
  value       = openstack_networking_secgroup_v2.db_sg.id
}

/*
I Security Groups in OpenStack funzionano in modo molto simile a quelli AWS,
con una differenza strutturale: in AWS le regole sono definite inline nel blocco
del security group, mentre in OpenStack ogni regola è una risorsa separata
(openstack_networking_secgroup_rule_v2) collegata al gruppo tramite security_group_id.

L'opzione delete_default_rules = true è importante: per default OpenStack crea
regole di egress permissive e regole che permettono tutto il traffico tra membri
dello stesso gruppo. Rimuovendole, abbiamo controllo esplicito su ogni flusso,
replicando il comportamento AWS dove ogni regola deve essere dichiarata.

Il parametro remote_group_id è l'equivalente OpenStack del "security_groups" di AWS:
permette di definire regole che accettano traffico solo da istanze appartenenti
a un altro security group, creando la stessa catena di fiducia LB -> Compute -> DB.

La sezione debug (regole sul default SG del VPC LocalStack) è stata omessa perché
in OpenStack non esiste un "VPC di default" con lo stesso comportamento. Le regole
di debug per la porta 8000 sono incluse direttamente nel compute_sg con apertura
globale (0.0.0.0/0), che è sufficiente per un ambiente di sviluppo.
*/
