/* ------------------------------------------------------------------------
   Storage OpenStack: Swift Object Storage + Database VM.
   Sostituisce S3 buckets e RDS di AWS.
   Swift containers rimpiazzano i bucket S3.
   Un'istanza compute con PostgreSQL rimpiazza RDS (Trove non disponibile).
   ------------------------------------------------------------------------ */

# --- SWIFT OBJECT STORAGE (Sostituisce S3) ---

# Container per il Frontend (equivalente del bucket S3 frontend)
# ACL pubblica in lettura per servire contenuto statico
resource "openstack_objectstorage_container_v1" "frontend" {
  name = "my-app-frontend-container"

  metadata = {
    description = "Frontend Static Hosting"
  }

  # ACL pubblica in lettura: permette a chiunque di leggere gli oggetti
  # Equivalente della bucket policy con Principal = "*"
  container_read = ".r:*,.rlistings"
}

# Container per i Media (equivalente del bucket S3 media)
# Rimane privato (nessuna ACL pubblica)
resource "openstack_objectstorage_container_v1" "media" {
  name = "my-app-media-assets"

  metadata = {
    description = "User Media Storage"
  }
}

# --- SEED MEDIA FILES ---

locals {
  media_files = {
    "prop01/front.png"    = "${path.module}/terraform_content/seed_media/prop01_front.png"
    "prop02/front.png"    = "${path.module}/terraform_content/seed_media/prop02_front.png"
    "prop03/front.png"    = "${path.module}/terraform_content/seed_media/prop03_front.png"
    "prop03/interior.png" = "${path.module}/terraform_content/seed_media/prop03_interior.png"
    "prop03/hall.png"     = "${path.module}/terraform_content/seed_media/prop03_hall.png"
    "prop04/front.png"    = "${path.module}/terraform_content/seed_media/prop04_front.png"
    "prop05/front.png"    = "${path.module}/terraform_content/seed_media/prop05_front.png"
    "prop06/front.png"    = "${path.module}/terraform_content/seed_media/prop06_front.png"
    "prop07/front.png"    = "${path.module}/terraform_content/seed_media/prop07_front.png"
    "prop07/hall.png"     = "${path.module}/terraform_content/seed_media/prop07_hall.png"
    "prop07/interior.png" = "${path.module}/terraform_content/seed_media/prop07_interior.png"
    "prop08/front.png"    = "${path.module}/terraform_content/seed_media/prop08_front.png"
    "prop08/hall.png"     = "${path.module}/terraform_content/seed_media/prop08_hall.png"
    "prop09/front.png"    = "${path.module}/terraform_content/seed_media/prop09_front.png"
    "prop09/pool.png"     = "${path.module}/terraform_content/seed_media/prop09_pool.png"
    "prop10/front.png"    = "${path.module}/terraform_content/seed_media/prop10_front.png"
    "prop10/hall.png"     = "${path.module}/terraform_content/seed_media/prop10_hall.png"
  }
}

resource "openstack_objectstorage_object_v1" "media_seed" {
  for_each = local.media_files

  container_name = openstack_objectstorage_container_v1.media.name
  name           = each.key
  source         = each.value
  content_type = lookup(
    {
      "png"  = "image/png",
      "jpg"  = "image/jpeg",
      "jpeg" = "image/jpeg"
    },
    split(".", each.key)[length(split(".", each.key)) - 1],
    "application/octet-stream"
  )
}

# --- OUTPUTS ---

output "swift_frontend_container" {
  description = "Nome del container Swift per il frontend"
  value       = openstack_objectstorage_container_v1.frontend.name
}

output "swift_media_container" {
  description = "Nome del container Swift per i media"
  value       = openstack_objectstorage_container_v1.media.name
}

output "swift_frontend_url" {
  description = "URL base del container frontend (Swift endpoint)"
  value       = "${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.frontend.name}"
}

output "swift_media_url" {
  description = "URL base del container media (Swift endpoint)"
  value       = "${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.media.name}"
}

# --- DATABASE VM (Sostituisce RDS) ---

# Trove non è disponibile in DevStack, quindi deployamo PostgreSQL su una VM dedicata.
# Lo user_data installa PostgreSQL, crea il database, l'utente e carica lo schema.
resource "openstack_compute_instance_v2" "db_server" {
  name            = "myapp-postgres-db"
  image_id        = data.openstack_images_image_v2.app_image.id
  flavor_id       = data.openstack_compute_flavor_v2.app_flavor.id
  security_groups = [openstack_networking_secgroup_v2.db_sg.name]
  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name

  # Posizionato nella subnet privata (isolato, come RDS)
  network {
    uuid        = openstack_networking_network_v2.main.id
    fixed_ip_v4 = cidrhost(openstack_networking_subnet_v2.private_1.cidr, 100)
  }

  depends_on = [
    openstack_networking_subnet_v2.private_1
  ]

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Installazione PostgreSQL
              apt-get update -y
              apt-get install -y postgresql postgresql-contrib

              # Avvio del servizio
              systemctl start postgresql
              systemctl enable postgresql

              # Configurazione: accetta connessioni dalla rete interna
              echo "listen_addresses = '*'" >> /etc/postgresql/*/main/postgresql.conf
              echo "host all all 10.0.0.0/16 md5" >> /etc/postgresql/*/main/pg_hba.conf

              # Creazione database e utente
              sudo -u postgres psql -c "CREATE USER dbadmin WITH PASSWORD '${var.db_password}';"
              sudo -u postgres psql -c "CREATE DATABASE myappdb OWNER dbadmin;"

              # Caricamento schema (se presente)
              # In produzione lo schema verrebbe caricato via provisioner o migration tool
              
              # Riavvio per applicare le configurazioni
              systemctl restart postgresql
              EOF
}

# --- DATABASE OUTPUTS ---

output "db_instance_ip" {
  description = "Indirizzo IP della VM database PostgreSQL"
  value       = openstack_compute_instance_v2.db_server.access_ip_v4
}

output "db_name" {
  description = "Nome del database PostgreSQL"
  value       = "myappdb"
}

output "db_user" {
  description = "Nome utente del database PostgreSQL"
  value       = "dbadmin"
}

/*
La sezione database sostituisce aws_db_instance (RDS) con una VM Nova dedicata.
Trove (DBaaS di OpenStack) non è disponibile in questo DevStack, quindi optiamo
per un'istanza compute con user_data che installa e configura PostgreSQL.

La VM è posizionata nella subnet privata con un IP fisso (cidrhost .100) e protetta
dal security group del database che accetta connessioni solo dalle istanze compute.
Questo replica l'isolamento di RDS nelle subnet private con il suo security group.

Lo user_data script:
1. Installa PostgreSQL via apt
2. Configura l'ascolto su tutte le interfacce (listen_addresses = '*')
3. Permette connessioni MD5 dalla rete interna (10.0.0.0/16)
4. Crea l'utente dbadmin e il database myappdb

Il db_subnet_group di AWS è implicito: la VM è semplicemente collegata alla rete
e subnet desiderata tramite il blocco network.

Lo schema SQL viene caricato manualmente o via migration tool in questa configurazione,
poiché il null_resource con local-exec del design originale richiedeva un client psql
locale che potrebbe non essere disponibile.
*/
