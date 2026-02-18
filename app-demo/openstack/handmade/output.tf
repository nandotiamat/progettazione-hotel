output "web_node_public_ip" {
  description = "The Floating IP of the web (Ubuntu with Apache) instance"
  value       = openstack_networking_floatingip_v2.web_fip.address
}

output "ssh_command" {
  description = "Run this command to connect to your instance"
  value       = "ssh -i main-key.pem ubuntu@${openstack_networking_floatingip_v2.web_fip.address}"
}

output "website_url" {
  description = "Click here to view your new static website" 
  value       = "http://${openstack_networking_floatingip_v2.web_fip.address}"
}
