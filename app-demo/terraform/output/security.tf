resource "openstack_networking_secgroup_v2" "backend" {
  name        = "${var.app_name}-backend"
  description = "Backend instances"
}

resource "openstack_networking_secgroup_rule_v2" "backend_ingress_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.backend_app_port
  port_range_max    = var.backend_app_port
  remote_ip_prefix  = var.network_cidr
  security_group_id = openstack_networking_secgroup_v2.backend.id
}

resource "openstack_networking_secgroup_rule_v2" "backend_ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_ingress_cidr
  security_group_id = openstack_networking_secgroup_v2.backend.id
}

resource "openstack_networking_secgroup_rule_v2" "backend_egress_all" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.backend.id
}

resource "openstack_networking_secgroup_v2" "db" {
  name        = "${var.app_name}-db"
  description = "Postgres database"
}

resource "openstack_networking_secgroup_rule_v2" "db_ingress_postgres" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.db_port
  port_range_max    = var.db_port
  remote_group_id   = openstack_networking_secgroup_v2.backend.id
  security_group_id = openstack_networking_secgroup_v2.db.id
}

resource "openstack_networking_secgroup_rule_v2" "db_ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_ingress_cidr
  security_group_id = openstack_networking_secgroup_v2.db.id
}

resource "openstack_networking_secgroup_rule_v2" "db_egress_all" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.db.id
}
