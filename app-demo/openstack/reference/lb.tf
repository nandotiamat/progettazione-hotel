# LOAD BALANCER
resource "openstack_lb_loadbalancer_v2" "hotel_lb" {
  name          = "hotel-lb"
  vip_subnet_id = openstack_networking_subnet_v2.hotel_private_subnet.id

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
resource "openstack_lb_member_v2" "hotel_lb_members" {
  count   = 2 # Si allinea perfettamente al tuo compute.tf
  name    = "web-node-${count.index + 1}"
  pool_id = openstack_lb_pool_v2.hotel_pool.id

  # Estrae dinamicamente l'IP: frontend[0] e frontend[1]
  address       = openstack_compute_instance_v2.frontend[count.index].access_ip_v4
  protocol_port = 8000
  subnet_id     = openstack_networking_subnet_v2.hotel_private_subnet.id
}

# HEALTH MONITOR
resource "openstack_lb_monitor_v2" "hotel_monitor" {
  name    = "hotel-health-monitor"
  pool_id = openstack_lb_pool_v2.hotel_pool.id

  # Usiamo il tipo TCP che abbiamo testato con successo via CLI
  type = "TCP"

  # La configurazione che abbiamo verificato con tcpdump
  delay       = 5
  timeout     = 3
  max_retries = 3

  # Opzionale: admin_state_up definisce se il monitor è attivo
  admin_state_up = true
}
