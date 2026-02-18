# --- 1. CHIAVE SSH (Opzionale ma vitale per il debug) ---
resource "openstack_compute_keypair_v2" "my_keypair" {
  name = "my-devstack-key"
  # Se ometti 'public_key', Terraform chiederà a OpenStack di generarne 
  # una nuova e potrai salvarla dagli output. Altrimenti puoi incollare la tua id_rsa.pub.
}

# resource "openstack_compute_instance_v2" "web_node" {
#   name            = "web-ubuntu-node"
#   image_name      = var.image_name
#   flavor_name     = var.flavor_name
#   key_pair        = openstack_compute_keypair_v2.main_key.name
#   
#   security_groups = [
#     openstack_networking_secgroup_v2.sg_web.name,
#     openstack_networking_secgroup_v2.sg_ssh.name,
#     openstack_networking_secgroup_v2.sg_internal.name
#   ]
# 
#   network {
#     uuid = openstack_networking_network_v2.main_net.id
#   }
# 
#   user_data = file("${path.module}/web-init.yaml")
# }

resource "openstack_compute_instance_v2" "debug_node" {
  name      = "myapp-manual-debug-node"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair  = openstack_compute_keypair_v2.my_keypair.name
  
  # IMPORTANTE: In questa risorsa specifica di Terraform per OpenStack, 
  # si usa il NOME del security group, non l'ID!
  security_groups = [openstack_networking_secgroup_v2.backend_sg.name]

  # La colleghiamo alla nostra rete privata creata al passo precedente
  network {
    uuid = openstack_networking_network_v2.private_net.id
  }

  # Lo stesso script del tuo codice AWS
  user_data = <<-EOF
              #!/bin/bash
              echo "Server on OpenStack (DevStack)" > index.html
              python3 -m http.server 8000 &
              EOF
}

# --- 4. FLOATING IP (Per accedere dal tuo browser/terminale) ---
# "Noleggiamo" un IP dalla rete pubblica
resource "openstack_networking_floatingip_v2" "debug_fip" {
  pool = data.openstack_networking_network_v2.ext_net.name 
}

# Associamo l'IP noleggiato alla macchina appena creata
resource "openstack_compute_floatingip_associate_v2" "debug_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.debug_fip.address
  instance_id = openstack_compute_instance_v2.debug_node.id
}

# --- OUTPUTS ---
output "debug_node_private_ip" {
  description = "L'IP interno della macchina (es. 10.0.1.x)"
  value       = openstack_compute_instance_v2.debug_node.access_ip_v4
}

output "debug_node_public_ip" {
  description = "Il Floating IP per collegarti via browser o SSH"
  value       = openstack_networking_floatingip_v2.debug_fip.address
}

# Salva la chiave privata generata sul tuo computer locale
resource "local_file" "private_key" {
  content         = openstack_compute_keypair_v2.my_keypair.private_key
  filename        = "${path.module}/my-devstack-key.pem"
  
  # FONDAMENTALE: SSH rifiuta le chiavi se i permessi sono troppo aperti.
  # 0600 significa che solo tu (il proprietario) puoi leggerla.
  file_permission = "0600" 
}

# --- LA MACCHINA VIRTUALE PER IL DATABASE ---
resource "openstack_compute_instance_v2" "db_node" {
  name        = "myapp-postgres-db"
  image_name  = var.image_name
  flavor_name = var.flavor_name
  key_pair    = openstack_compute_keypair_v2.my_keypair.name
  
  # Usiamo il Security Group del DB che avevamo già creato!
  security_groups = [openstack_networking_secgroup_v2.db_sg.name]

  # Lo colleghiamo alla solita rete privata
  network {
    uuid = openstack_networking_network_v2.private_net.id
  }

  # Leggiamo il file YAML creato al passo 1
  user_data = file("${path.module}/cloud-init-db.yaml")
}

# --- OUTPUT ---
output "db_private_ip" {
  description = "L'IP privato del database (es. 10.0.1.X) da passare alle app backend"
  value       = openstack_compute_instance_v2.db_node.access_ip_v4
}
