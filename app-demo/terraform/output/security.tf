resource "openstack_networking_secgroup_v2" "bastion" {
  name        = "bastion_sg"
  description = "Bastion: SSH from anywhere"
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_v2" "frontend" {
  name        = "frontend_sg"
  description = "Frontend: HTTP from anywhere; SSH from bastion SG"
}

resource "openstack_networking_secgroup_rule_v2" "frontend_ingress_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.frontend.id
}

resource "openstack_networking_secgroup_rule_v2" "frontend_ingress_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.frontend.id
}

resource "openstack_networking_secgroup_v2" "backend" {
  name        = "backend_sg"
  description = "Backend: HTTP from anywhere; SSH from frontend SG"
}

resource "openstack_networking_secgroup_rule_v2" "backend_ingress_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.backend.id
}

resource "openstack_networking_secgroup_rule_v2" "backend_ingress_ssh_from_frontend" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.frontend.id
  security_group_id = openstack_networking_secgroup_v2.backend.id
}

resource "openstack_networking_secgroup_v2" "db" {
  name        = "db_sg"
  description = "DB: Postgres from backend SG"
}

resource "openstack_networking_secgroup_rule_v2" "db_ingress_postgres_from_backend" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.backend.id
  security_group_id = openstack_networking_secgroup_v2.db.id
}
