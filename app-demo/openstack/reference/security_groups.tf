# Since we are using OCTAVIA (LB) with provider OVN, the load balancing happens at layer 4 (TCP), instead of HTTP (layer 7)
# This means that we are not using HAProxies (actual VMs), BUT a magic trick that happens at switch level.
resource "openstack_networking_secgroup_v2" "frontend_sg" {
  name        = "frontend-security-group"
  description = "Permette traffico dal Load Balancer (in realtà, dal mondo, perchè stiamo usando Octavia con provider OVN) ai nodi di frontend"
}

# Even if we set 0.0.0.0/0, we cant reach those vm from the outside world without the lb
resource "openstack_networking_secgroup_rule_v2" "frontend_http_from_world" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8000
  port_range_max    = 8000
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.frontend_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "debug_frontend_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.frontend_sg.id
}

# --- 2. SECURITY GROUP PER IL BACKEND (Nova Compute / EC2) ---
resource "openstack_networking_secgroup_v2" "backend_sg" {
  name        = "backend-security-group"
  description = "Permette traffico dal Load Balancer e SSH interno"
}

# Useful for Rest API calls to the FastAPI (HTTP Requests)
resource "openstack_networking_secgroup_rule_v2" "backend_http_from_frontend" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8000
  port_range_max    = 8000
  remote_group_id   = openstack_networking_secgroup_v2.frontend_sg.id
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

# SSH consentito SOLO dalla nostra rete privata (usando la variabile del CIDR)
resource "openstack_networking_secgroup_rule_v2" "backend_ssh_internal" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.frontend_sg.id
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

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
