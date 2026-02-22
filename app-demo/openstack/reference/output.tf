output "frontend_private_ips" {
  description = "L'IP privati dei nodi frontend (es. [10.0.1.x, 10.0.1.y])"
  value       = openstack_compute_instance_v2.frontend[*].access_ip_v4
}

output "frontend_public_ip" {
  description = "Il Floating IP per collegarti via browser o SSH ad uno dei frontend."
  value       = openstack_networking_floatingip_v2.frontend_fip.address
}

output "db_private_ip" {
  description = "L'IP privato del database (es. 10.0.1.X) da passare alle app backend"
  value       = openstack_compute_instance_v2.db.access_ip_v4
}

output "backend_public_ip" {
  description = "Il Floating IP per collegarti via browser o SSH"
  value       = openstack_networking_floatingip_v2.backend_fip.address
}

output "swift_media_container_name" {
  description = "Il nome del container Swift per i media"
  value       = openstack_objectstorage_container_v1.media_container.name
}

output "load_balancer_public_ip" {
  description = "L'indirizzo IP pubblico definitivo del tuo Load Balancer"
  value       = openstack_networking_floatingip_v2.lb_fip.address
}
