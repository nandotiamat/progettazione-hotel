# output/security.tf
resource "openstack_networking_secgroup_v2" "app_sg" {
  name        = "app_security_group"
  description = "Security group for application instances"
}

resource "openstack_networking_secgroup_rule_v2" "app_sg_rule_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app_sg.id
}
