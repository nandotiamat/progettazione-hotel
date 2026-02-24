/* ------------------------------------------------------------------------
   Compute OpenStack: Load Balancer (Octavia) + Istanze Nova + Debug Instance.
   Equivalente di compute.tf AWS che conteneva ALB, ASG, Launch Template,
   CloudWatch alarm, scaling policy e istanza di debug.

   In OpenStack:
   - ALB → Octavia LB (OVN provider, L4 only)
   - ASG + Launch Template → N istanze Nova con count
   - CloudWatch + Scaling Policy → Omessi (nessun Ceilometer/Aodh)
   - Debug instance → Istanza Nova sulla subnet pubblica
   ------------------------------------------------------------------------ */

# --- LOAD BALANCER (OCTAVIA) ---

# Data sources per immagini e flavor (usati da tutte le istanze)
data "openstack_images_image_v2" "compute_image" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "compute_flavor" {
  name = var.flavor_name
}

data "openstack_compute_flavor_v2" "debug_flavor" {
  name = var.debug_flavor_name
}

# Load Balancer Octavia (equivalente dell'ALB AWS)
# Posizionato sulla prima subnet pubblica per ricevere traffico esterno
resource "openstack_lb_loadbalancer_v2" "app_lb" {
  name               = "myapp-load-balancer"
  vip_subnet_id      = openstack_networking_subnet_v2.public_1.id
  security_group_ids = [openstack_networking_secgroup_v2.lb_sg.id]

  depends_on = [
    openstack_networking_router_interface_v2.public_1
  ]
}

# Listener sulla porta 80 (equivalente dell'aws_lb_listener)
resource "openstack_lb_listener_v2" "http" {
  name            = "myapp-http-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.app_lb.id
}

# Pool di backend (equivalente dell'aws_lb_target_group)
resource "openstack_lb_pool_v2" "app_pool" {
  name        = "myapp-backend-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.http.id
}

# Health Monitor (equivalente dell'health_check nel target group AWS)
# Thresholds rilassati per DevStack (come nell'originale con matcher "200-499")
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

# --- ISTANZE COMPUTE (Sostituzione ASG + Launch Template) ---

# N istanze Nova che sostituiscono l'ASG con desired_capacity
# Ogni istanza viene posizionata sulla subnet privata e riceve il security group compute
resource "openstack_compute_instance_v2" "backend" {
  count           = var.instance_count
  name            = "myapp-backend-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.compute_image.id
  flavor_id       = data.openstack_compute_flavor_v2.compute_flavor.id
  security_groups = [openstack_networking_secgroup_v2.compute_sg.name]

  network {
    uuid = openstack_networking_network_v2.main.id
  }

  # User data equivalente al launch template AWS
  # In un ambiente reale, qui andrebbe lo script di deploy del backend
  user_data = <<-EOF
    #!/bin/bash
    echo "Backend instance ${count.index + 1}" > index.html
    python3 -m http.server ${var.app_port} &
    EOF

  depends_on = [
    openstack_networking_subnet_v2.private_1,
    openstack_networking_subnet_v2.private_2
  ]
}

# Registrazione delle istanze nel pool del LB (equivalente dell'ASG target_group_arns)
resource "openstack_lb_member_v2" "backend" {
  count         = var.instance_count
  pool_id       = openstack_lb_pool_v2.app_pool.id
  address       = openstack_compute_instance_v2.backend[count.index].access_ip_v4
  protocol_port = var.app_port
  subnet_id     = openstack_networking_subnet_v2.private_1.id
}

# --- ISTANZA DI DEBUG ---

# Istanza di debug sulla subnet pubblica (equivalente dell'aws_instance manual_debug_node)
resource "openstack_compute_instance_v2" "debug" {
  name            = "myapp-debug-node"
  image_id        = data.openstack_images_image_v2.compute_image.id
  flavor_id       = data.openstack_compute_flavor_v2.debug_flavor.id
  security_groups = [openstack_networking_secgroup_v2.compute_sg.name]

  network {
    uuid = openstack_networking_network_v2.main.id
  }

  user_data = <<-EOF
    #!/bin/bash
    echo "Server on Debug Instance (Public Subnet)" > index.html
    python3 -m http.server ${var.app_port} &
    EOF

  depends_on = [
    openstack_networking_subnet_v2.public_1
  ]
}

# Floating IP per l'istanza di debug (per accesso diretto dall'esterno)
resource "openstack_networking_floatingip_v2" "debug_fip" {
  pool = var.external_network_name
}

resource "openstack_compute_floatingip_associate_v2" "debug_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.debug_fip.address
  instance_id = openstack_compute_instance_v2.debug.id
}

# Floating IP per il Load Balancer (per accesso dall'esterno)
resource "openstack_networking_floatingip_v2" "lb_fip" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.app_lb.vip_port_id
}

# --- NOTA: AUTOSCALING E MONITORAGGIO ---
# Le seguenti risorse AWS sono state omesse perché non disponibili in OpenStack
# senza Ceilometer/Aodh/Heat:
# - aws_cloudwatch_metric_alarm (monitoraggio CPU)
# - aws_autoscaling_policy (scaling automatico)
# - aws_autoscaling_group (gruppo auto-scalante)
# Il numero di istanze è fisso (var.instance_count) e va modificato manualmente.

# --- OUTPUTS ---

output "lb_vip_address" {
  description = "Indirizzo VIP interno del Load Balancer"
  value       = openstack_lb_loadbalancer_v2.app_lb.vip_address
}

output "lb_floating_ip" {
  description = "IP pubblico (floating) del Load Balancer"
  value       = openstack_networking_floatingip_v2.lb_fip.address
}

output "debug_floating_ip" {
  description = "IP pubblico (floating) dell'istanza di debug"
  value       = openstack_networking_floatingip_v2.debug_fip.address
}

output "backend_instance_ips" {
  description = "Indirizzi IP delle istanze backend"
  value       = openstack_compute_instance_v2.backend[*].access_ip_v4
}

/*
Questo file implementa il layer compute dell'applicazione, traducendo il pattern
AWS ALB + ASG in un equivalente OpenStack con Octavia + istanze Nova statiche.

L'Octavia Load Balancer con provider OVN opera a livello L4 (TCP/UDP), non L7
come l'ALB AWS. Tuttavia, il design originale AWS usava solo un listener HTTP
sulla porta 80 con azione "forward-all", senza path-based routing, quindi
la limitazione L4 è accettabile.

Le istanze backend sono create con `count` anziché con un ASG, il che significa
che il numero è fisso e non si scala automaticamente. La variabile `instance_count`
controlla quante istanze vengono create (default: 2, come il `desired_capacity`
dell'ASG originale).

Le Floating IP sono necessarie in OpenStack per esporre servizi all'esterno della
rete virtuale. Non esiste un equivalente diretto dell'"ALB pubblico" AWS — il VIP
di Octavia è interno alla subnet, quindi serve una Floating IP per renderlo
raggiungibile. Lo stesso vale per l'istanza di debug.

L'health monitor usa `expected_codes = "200-499"` per replicare il matcher rilassato
dell'originale AWS, che accettava anche 404 perché le istanze partono senza un
server HTTP configurato.
*/
