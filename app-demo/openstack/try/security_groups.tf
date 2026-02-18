# Traffico in uscita (Egress): Quando crei un SG in OpenStack, di default vengono aggiunte automaticamente due regole (IPv4 e IPv6) che permettono tutto il traffico in uscita. 
# Esattamente come facevi in AWS con egress { to_port = 0 ... }. Quindi non dobbiamo scriverle!

resource "openstack_networking_secgroup_v2" "lb_sg" {
  name        = "lb-security-group"
  description = "Permette traffico HTTP/HTTPS dal mondo esterno verso il Load Balancer"
}

# Aggiungiamo due rules per il traffico in ingresso su porta 80 (HTTP) e 443 (HTTPS)

resource "openstack_networking_secgroup_rule_v2" "lb_http_in" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "lb_https_in" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.lb_sg.id
}

# --- 2. SECURITY GROUP PER IL BACKEND (Nova Compute / EC2) ---
resource "openstack_networking_secgroup_v2" "backend_sg" {
  name        = "backend-security-group"
  description = "Permette traffico dal Load Balancer e SSH interno"
}

# La magia: accetta porta 80 SOLO se il traffico proviene dal Security Group del LB
resource "openstack_networking_secgroup_rule_v2" "backend_http_from_lb" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = openstack_networking_secgroup_v2.lb_sg.id # <--- Il collegamento!
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

# Porta 8000 aperta per il tuo debug (come nel tuo script originale)
resource "openstack_networking_secgroup_rule_v2" "backend_debug_8000" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8000
  port_range_max    = 8000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

# SSH consentito SOLO dalla nostra rete privata (10.0.1.0/24)
resource "openstack_networking_secgroup_rule_v2" "backend_ssh_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

# --- 3. SECURITY GROUP PER IL DATABASE (Trove / DB Istanza) ---
resource "openstack_networking_secgroup_v2" "db_sg" {
  name        = "db-security-group"
  description = "Permette traffico PostgreSQL esclusivamente dai server Backend"
}

# Accetta connessioni Postgres (5432) SOLO dal Security Group del Backend
resource "openstack_networking_secgroup_rule_v2" "db_postgres_from_backend" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.backend_sg.id
  security_group_id = openstack_networking_secgroup_v2.db_sg.id
}
