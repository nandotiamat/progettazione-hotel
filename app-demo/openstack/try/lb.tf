# LOAD BALANCER
resource "openstack_lb_loadbalancer_v2" "hotel_lb" {
  name          = "hotel-lb"
  vip_subnet_id = openstack_networking_subnet_v2.private_subnet.id
  
  # Specifichiamo esplicitamente il motore OVN
  loadbalancer_provider = "ovn"
}

# LISTENER
resource "openstack_lb_listener_v2" "hotel_listener" {
  name            = "hotel-listener"
  protocol        = "TCP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.hotel_lb.id
}

# POOL 
resource "openstack_lb_pool_v2" "hotel_pool" {
  name        = "hotel-pool"
  protocol    = "TCP"
  lb_method   = "SOURCE_IP_PORT" # L'algoritmo perfetto per OVN
  listener_id = openstack_lb_listener_v2.hotel_listener.id
}

# MEMBERS 
resource "openstack_lb_member_v2" "web_node_1" {
  name          = "web-node-1"
  pool_id       = openstack_lb_pool_v2.hotel_pool.id

  # Terraform estrae in automatico l'IP del primo nodo
  address       = openstack_compute_instance_v2.debug_node.access_ip_v4
  protocol_port = 8000
  subnet_id     = openstack_networking_subnet_v2.private_subnet.id
}

resource "openstack_lb_member_v2" "web_node_2" {
  name          = "web-node-2"
  pool_id       = openstack_lb_pool_v2.hotel_pool.id

  # Terraform estrae in automatico l'IP del secondo nodo
  address       = openstack_compute_instance_v2.debug_node2.access_ip_v4
  protocol_port = 8000
  subnet_id     = openstack_networking_subnet_v2.private_subnet.id
}

# HEALTH MONITOR
resource "openstack_lb_monitor_v2" "hotel_monitor" {
  name           = "hotel-health-monitor"
  pool_id        = openstack_lb_pool_v2.hotel_pool.id
  
  # Usiamo il tipo TCP che abbiamo testato con successo via CLI
  type           = "TCP"
  
  # La configurazione che abbiamo verificato con tcpdump
  delay          = 5
  timeout        = 3
  max_retries    = 3
  
  # Opzionale: admin_state_up definisce se il monitor è attivo
  admin_state_up = true
}

# FLOATING IP 
resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name
}

# Associamo il Floating IP alla porta VIP del Load Balancer
resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.hotel_lb.vip_port_id
}

# --- OUTPUT FINALE ---
output "load_balancer_public_ip" {
  description = "L'indirizzo IP pubblico definitivo del tuo Load Balancer"
  value       = openstack_networking_floatingip_v2.lb_fip.address
}

