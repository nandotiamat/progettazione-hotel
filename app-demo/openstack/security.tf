# --- SECURITY GROUPS ---

# 1. SSH Access (Debug)
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

# 2. Web Access (Public HTTP/HTTPS)
resource "openstack_networking_secgroup_v2" "sg_web" {
  name        = "sg_web"
  description = "Allow HTTP/HTTPS from anywhere"
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

resource "openstack_networking_secgroup_rule_v2" "rule_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_web.id
}

# 3. Internal Communication (Allow all internal traffic in the subnet)
resource "openstack_networking_secgroup_v2" "sg_internal" {
  name        = "sg_internal"
  description = "Allow all internal traffic"
}

resource "openstack_networking_secgroup_rule_v2" "rule_internal_all" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "192.168.1.0/24"
  security_group_id = openstack_networking_secgroup_v2.sg_internal.id
}

# Allow ICMP for ping
resource "openstack_networking_secgroup_rule_v2" "rule_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.sg_internal.id
}
