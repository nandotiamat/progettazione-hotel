output "lb_floating_ip" {
  value       = openstack_networking_floatingip_v2.lb.address
  description = "Public floating IP for the Octavia VIP."
}

output "lb_http_endpoint" {
  value       = "http://${openstack_networking_floatingip_v2.lb.address}:${var.lb_listen_port}"
  description = "HTTP endpoint for the load balancer."
}

output "backend_instance_ipv4" {
  value       = local.backend_fixed_ipv4
  description = "Backend instance IPv4 addresses (tenant network)."
}

output "db_instance_ipv4" {
  value       = local.db_fixed_ipv4
  description = "DB instance IPv4 address (tenant network)."
}

output "swift_containers" {
  value = {
    frontend = openstack_objectstorage_container_v1.frontend.name
    media    = openstack_objectstorage_container_v1.media.name
  }
  description = "Swift container names."
}

output "env_file" {
  value       = local_file.env.filename
  description = "Path to generated dotenv file on the Terraform runner."
}
