/* ------------------------------------------------------------------------
   Load Balancer Octavia con provider OVN (Layer 4 TCP).
   Espone i due nodi frontend sulla porta 80 tramite un pool con
   health monitoring TCP. La floating IP e' associata al VIP.
   ------------------------------------------------------------------------ */

# --- LOAD BALANCER ---

# LB Octavia con provider OVN sulla subnet privata
resource "openstack_lb_loadbalancer_v2" "hotel_lb" {
  name                  = "hotel-lb"
  loadbalancer_provider = "ovn"
  vip_subnet_id         = openstack_networking_subnet_v2.hotel_subnet.id
}

# --- LISTENER ---

# Listener TCP sulla porta 80 (OVN supporta solo Layer 4)
resource "openstack_lb_listener_v2" "http_listener" {
  name            = "hotel-http-listener"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.hotel_lb.id
}

# --- POOL ---

# Pool di backend con algoritmo SOURCE_IP_PORT per distribuzione del traffico
resource "openstack_lb_pool_v2" "frontend_pool" {
  name        = "hotel-frontend-pool"
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT"
  listener_id = openstack_lb_listener_v2.http_listener.id
}

# --- MEMBRI DEL POOL ---

# Membro 1: frontend-1
resource "openstack_lb_member_v2" "frontend_member_1" {
  pool_id       = openstack_lb_pool_v2.frontend_pool.id
  address       = openstack_compute_instance_v2.frontend[0].access_ip_v4
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.hotel_subnet.id
}

# Membro 2: frontend-2
resource "openstack_lb_member_v2" "frontend_member_2" {
  pool_id       = openstack_lb_pool_v2.frontend_pool.id
  address       = openstack_compute_instance_v2.frontend[1].access_ip_v4
  protocol_port = 80
  subnet_id     = openstack_networking_subnet_v2.hotel_subnet.id
}

# --- HEALTH MONITOR ---

# Monitor TCP per verificare la disponibilita' dei nodi frontend
resource "openstack_lb_monitor_v2" "tcp_monitor" {
  pool_id     = openstack_lb_pool_v2.frontend_pool.id
  type        = "TCP"
  delay       = 5
  timeout     = 3
  max_retries = 3
}

# --- ASSOCIAZIONE FLOATING IP AL VIP ---

# Associa la floating IP allocata in network.tf alla porta VIP del load balancer
resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.hotel_lb.vip_port_id
}

# --- OUTPUTS ---

output "lb_vip_address" {
  description = "Indirizzo VIP privato del load balancer"
  value       = openstack_lb_loadbalancer_v2.hotel_lb.vip_address
}

output "lb_floating_ip_address" {
  description = "Floating IP pubblica del load balancer"
  value       = openstack_networking_floatingip_v2.lb_fip.address
}
