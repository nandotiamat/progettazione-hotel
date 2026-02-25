/* ------------------------------------------------------------------------
   Compute OpenStack: Load Balancer (Octavia) + Istanze (Nova).
   Sostituisce ALB, ASG, Launch Template, CloudWatch alarm di AWS.
   Octavia con OVN provider è L4 only (no L7 path-based routing).
   ------------------------------------------------------------------------ */

# --- LOAD BALANCER (OCTAVIA) ---

# Load Balancer sulla subnet pubblica (equivalente di aws_lb ALB)
resource "openstack_lb_loadbalancer_v2" "app_lb" {
  name           = "myapp-load-balancer"
  vip_subnet_id  = openstack_networking_subnet_v2.public_1.id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.lb_sg.id]
}

# Listener HTTP sulla porta 80 (equivalente di aws_lb_listener)
resource "openstack_lb_listener_v2" "http" {
  name            = "myapp-http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.app_lb.id
  admin_state_up  = true
}

# Pool di backend (equivalente di aws_lb_target_group)
resource "openstack_lb_pool_v2" "app_pool" {
  name        = "myapp-backend-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.http.id
}

# Health Monitor (equivalente dell'health_check nel target group AWS)
# Soglie rilassate per DevStack (come nel design originale per LocalStack)
resource "openstack_lb_monitor_v2" "app_monitor" {
  name           = "myapp-health-monitor"
  pool_id        = openstack_lb_pool_v2.app_pool.id
  type           = "HTTP"
  http_method    = "GET"
  url_path       = "/"
  expected_codes = "200-499"
  delay          = 10
  timeout        = 5
  max_retries    = 10
}

# --- DATA SOURCES (Immagine e Flavor) ---

# Riferimento all'immagine Glance disponibile in DevStack
data "openstack_images_image_v2" "app_image" {
  name        = var.image_name
  most_recent = true
}

# Riferimento al flavor Nova disponibile in DevStack
data "openstack_compute_flavor_v2" "app_flavor" {
  name = var.flavor_name
}

# --- ISTANZE COMPUTE (Sostituiscono ASG + Launch Template) ---

# OpenStack non ha Auto Scaling Group nativo.
# Usiamo count = 2 per simulare desired_capacity = 2 dell'ASG originale.
resource "openstack_compute_instance_v2" "backend" {
  count           = 2
  name            = "myapp-backend-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.app_image.id
  flavor_id       = data.openstack_compute_flavor_v2.app_flavor.id
  security_groups = [openstack_networking_secgroup_v2.compute_sg.name]

  # Collegamento alla subnet privata (alternando tra le due)
  network {
    uuid = openstack_networking_network_v2.main.id
    fixed_ip_v4 = cidrhost(
      count.index % 2 == 0
      ? openstack_networking_subnet_v2.private_1.cidr
      : openstack_networking_subnet_v2.private_2.cidr,
      10 + count.index
    )
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Backend instance ${count.index + 1}" > index.html
              python3 -m http.server 8000 &
              EOF
}

# Registrazione delle istanze nel pool Octavia (equivalente di ASG target_group_arns)
resource "openstack_lb_member_v2" "backend" {
  count         = 2
  pool_id       = openstack_lb_pool_v2.app_pool.id
  address       = openstack_compute_instance_v2.backend[count.index].access_ip_v4
  protocol_port = 80
  subnet_id     = count.index % 2 == 0 ? openstack_networking_subnet_v2.private_1.id : openstack_networking_subnet_v2.private_2.id
}

# --- ISTANZA DI DEBUG ---

# Istanza equivalente al manual_debug_node di AWS
# Posizionata sulla subnet pubblica per accesso diretto
resource "openstack_compute_instance_v2" "debug_node" {
  name            = "myapp-debug-node"
  image_id        = data.openstack_images_image_v2.app_image.id
  flavor_id       = data.openstack_compute_flavor_v2.app_flavor.id
  security_groups = [openstack_networking_secgroup_v2.compute_sg.name]

  network {
    uuid = openstack_networking_network_v2.main.id
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Debug node on public subnet" > index.html
              python3 -m http.server 8000 &
              EOF
}

# Skipped: CloudWatch alarm + autoscaling policy (no Ceilometer/Aodh in DevStack)

# --- OUTPUTS ---

output "lb_vip_address" {
  description = "Indirizzo VIP del Load Balancer (sostituisce ALB DNS name)"
  value       = openstack_lb_loadbalancer_v2.app_lb.vip_address
}

output "backend_instance_ips" {
  description = "Indirizzi IP delle istanze backend"
  value       = openstack_compute_instance_v2.backend[*].access_ip_v4
}

output "debug_node_ip" {
  description = "Indirizzo IP dell'istanza di debug"
  value       = openstack_compute_instance_v2.debug_node.access_ip_v4
}

/*
Questo file combina Load Balancer e Compute, sostituendo l'intera architettura
ALB + ASG + Launch Template + CloudWatch di AWS.

Il Load Balancer Octavia opera su L4 (TCP/HTTP forwarding) con il provider OVN.
Non supporta routing basato su path come l'ALB AWS, ma il design originale
usava solo un semplice forward-all listener, quindi non c'è perdita funzionale.

Le istanze compute usano `count = 2` per simulare l'ASG con desired_capacity = 2.
Non c'è auto-scaling dinamico poiché DevStack non ha Heat, Ceilometer o Aodh.
Le istanze sono distribuite tra le subnet private con IP fissi calcolati tramite
cidrhost() per garantire posizionamento deterministico.

I membri del pool Octavia (openstack_lb_member_v2) collegano le istanze al LB,
sostituendo il meccanismo automatico di registrazione dell'ASG nel target group AWS.
*/
