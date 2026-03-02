output "bastion_floating_ip" {
  value       = openstack_networking_floatingip_v2.bastion.address
  description = "Public IP for the bastion host (SSH entrypoint)."
}

output "lb_floating_ip" {
  value       = openstack_networking_floatingip_v2.lb.address
  description = "Public IP for the Octavia LB VIP (TCP/80)."
}
