resource "openstack_networking_secgroup_v2" "sg_ssh" {
  name        = "sg_ssh"
  description = "Allow SSH from anywhere"
}

resource "openstack_networking_secgroup_rule_v2" "rule_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_ssh.id
}

resource "openstack_networking_secgroup_v2" "sg_internal" {
  name        = "sg_internal"
  description = "Allow internal subnet traffic and external ICMP (Ping)"
}

resource "openstack_networking_secgroup_rule_v2" "rule_internal_tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = var.internal_subnet_cidr 
  security_group_id = openstack_networking_secgroup_v2.sg_internal.id
}

resource "openstack_networking_secgroup_rule_v2" "rule_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0" 
  security_group_id = openstack_networking_secgroup_v2.sg_internal.id
}

resource "openstack_networking_secgroup_v2" "sg_web" {
  name        = "sg_web"
  description = "Allow HTTP web traffic"
}

resource "openstack_networking_secgroup_rule_v2" "rule_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80 
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_web.id
}
