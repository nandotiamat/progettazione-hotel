/* ------------------------------------------------------------------------
   Risorse di calcolo: immagine Glance, flavor, keypair SSH e 5 istanze Nova.
   - 2 frontend (Nginx, Ubuntu Jammy)
   - 1 backend (FastAPI, Ubuntu Jammy)
   - 1 database (PostgreSQL, Ubuntu Jammy)
   - 1 bastion (Cirros, accesso SSH)
   ------------------------------------------------------------------------ */

# --- IMMAGINE GLANCE ---

# Upload dell'immagine Ubuntu Jammy cloud-img in Glance
resource "openstack_images_image_v2" "ubuntu_jammy" {
  name             = "ubuntu-jammy-cloudimg"
  image_source_url = var.image_url
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
}

# Data source per l'immagine Cirros gia' presente in DevStack
data "openstack_images_image_v2" "cirros" {
  name_regex  = "^cirros-.*"
  most_recent = true
}

# --- FLAVOR ---

# Flavor personalizzato per le istanze hotel (1 vCPU, 2GB RAM, 10GB disco)
resource "openstack_compute_flavor_v2" "hotel_flavor" {
  name      = "hotel_flavor"
  vcpus     = 1
  ram       = 2048
  disk      = 10
  is_public = true
}

# --- KEYPAIR SSH ---

# Generazione chiave RSA per accesso SSH alle istanze
resource "tls_private_key" "hotel_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Registrazione della chiave pubblica in OpenStack
resource "openstack_compute_keypair_v2" "hotel_keypair" {
  name       = "hotel-keypair"
  public_key = tls_private_key.hotel_ssh_key.public_key_openssh
}

# Salvataggio della chiave privata su filesystem locale
resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.hotel_ssh_key.private_key_pem
  filename        = var.keypair_private_key_path
  file_permission = "0600"
}

# --- ISTANZE FRONTEND (x2) ---

# Due nodi frontend con Nginx, dietro al load balancer
resource "openstack_compute_instance_v2" "frontend" {
  count = 2

  name            = "hotel-frontend-${count.index + 1}"
  image_id        = openstack_images_image_v2.ubuntu_jammy.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.frontend_sg.id]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = templatefile("${path.module}/cloud-init/frontend-init-node.yaml", {
    node_index = count.index + 1
  })
}

# --- ISTANZA BACKEND ---

# Nodo backend con FastAPI/Uvicorn
resource "openstack_compute_instance_v2" "backend" {
  name            = "hotel-backend"
  image_id        = openstack_images_image_v2.ubuntu_jammy.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.backend_sg.id]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = file("${path.module}/cloud-init/backend-init-node.yaml")
}

# --- ISTANZA DATABASE ---

# Nodo database con PostgreSQL configurato via cloud-init
resource "openstack_compute_instance_v2" "database" {
  name            = "hotel-database"
  image_id        = openstack_images_image_v2.ubuntu_jammy.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.database_sg.id]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }

  user_data = templatefile("${path.module}/cloud-init/cloud-init-db.yaml", {
    db_user     = var.db_user
    db_password = var.db_password
    db_name     = var.db_name
    subnet_cidr = var.private_network_cidr
  })
}

# --- ISTANZA BASTION ---

# Bastion host con immagine Cirros — gateway SSH verso le altre istanze
resource "openstack_compute_instance_v2" "bastion" {
  name            = "hotel-bastion"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
  security_groups = [openstack_networking_secgroup_v2.bastion_sg.id]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }
}

# --- ASSOCIAZIONE FLOATING IP BASTION ---

data "openstack_networking_port_v2" "bastion_port" {
  device_id  = openstack_compute_instance_v2.bastion.id
  network_id = openstack_networking_network_v2.hotel_net.id
}

resource "openstack_networking_floatingip_associate_v2" "bastion_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
  port_id     = data.openstack_networking_port_v2.bastion_port.id
}

# --- OUTPUTS ---

output "frontend_ips" {
  description = "Lista degli IP privati dei nodi frontend"
  value       = openstack_compute_instance_v2.frontend[*].access_ip_v4
}

output "backend_ip" {
  description = "IP privato del nodo backend"
  value       = openstack_compute_instance_v2.backend.access_ip_v4
}

output "database_ip" {
  description = "IP privato del nodo database"
  value       = openstack_compute_instance_v2.database.access_ip_v4
}

output "bastion_ip" {
  description = "IP privato del bastion host"
  value       = openstack_compute_instance_v2.bastion.access_ip_v4
}

output "bastion_floating_ip_address" {
  description = "Floating IP pubblica del bastion host"
  value       = openstack_networking_floatingip_v2.bastion_fip.address
}
