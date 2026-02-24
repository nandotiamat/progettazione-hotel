/* ------------------------------------------------------------------------
   Storage OpenStack: Swift containers (S3 equivalent) e VM PostgreSQL (RDS equivalent).
   - Il frontend bucket diventa un container Swift con ACL pubblica in lettura
   - Il media bucket diventa un container Swift privato
   - RDS viene sostituito da una VM Nova con PostgreSQL installato via user_data
   - Il seeding dei media viene fatto con openstack_objectstorage_object_v1
   ------------------------------------------------------------------------ */

# --- SEZIONE OBJECT STORAGE (SWIFT) ---

# Container Swift per il Frontend (equivalente del bucket S3 con website hosting)
# ACL pubblica in lettura per servire contenuti statici direttamente da Swift
resource "openstack_objectstorage_container_v1" "frontend" {
  name = "my-app-frontend-container"

  metadata = {
    "Web-Index" = "index.html"
    "Web-Error" = "index.html"
    "Read"      = ".r:*,.rlistings"
  }

  # force_destroy equivalente: il container sarà cancellabile anche con oggetti dentro
  force_destroy = true
}

# Container Swift per i Media (equivalente del bucket S3 media, privato)
resource "openstack_objectstorage_container_v1" "media" {
  name = "my-app-media-assets"

  force_destroy = true
}

# --- SEEDING MEDIA (Equivalente degli aws_s3_object) ---

locals {
  media_files = {
    "prop01/front.png"    = "${path.module}/../terraform_content/seed_media/prop01_front.png"
    "prop02/front.png"    = "${path.module}/../terraform_content/seed_media/prop02_front.png"
    "prop03/front.png"    = "${path.module}/../terraform_content/seed_media/prop03_front.png"
    "prop03/interior.png" = "${path.module}/../terraform_content/seed_media/prop03_interior.png"
    "prop03/hall.png"     = "${path.module}/../terraform_content/seed_media/prop03_hall.png"
    "prop04/front.png"    = "${path.module}/../terraform_content/seed_media/prop04_front.png"
    "prop05/front.png"    = "${path.module}/../terraform_content/seed_media/prop05_front.png"
    "prop06/front.png"    = "${path.module}/../terraform_content/seed_media/prop06_front.png"
    "prop07/front.png"    = "${path.module}/../terraform_content/seed_media/prop07_front.png"
    "prop07/hall.png"     = "${path.module}/../terraform_content/seed_media/prop07_hall.png"
    "prop07/interior.png" = "${path.module}/../terraform_content/seed_media/prop07_interior.png"
    "prop08/front.png"    = "${path.module}/../terraform_content/seed_media/prop08_front.png"
    "prop08/hall.png"     = "${path.module}/../terraform_content/seed_media/prop08_hall.png"
    "prop09/front.png"    = "${path.module}/../terraform_content/seed_media/prop09_front.png"
    "prop09/pool.png"     = "${path.module}/../terraform_content/seed_media/prop09_pool.png"
    "prop10/front.png"    = "${path.module}/../terraform_content/seed_media/prop10_front.png"
    "prop10/hall.png"     = "${path.module}/../terraform_content/seed_media/prop10_hall.png"
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

# --- SEZIONE DATABASE (VM PostgreSQL) ---

# Data source per l'immagine Glance
data "openstack_images_image_v2" "db_image" {
  name        = var.image_name
  most_recent = true
}

# Data source per il flavor
data "openstack_compute_flavor_v2" "db_flavor" {
  name = var.db_flavor_name
}

# VM con PostgreSQL installato (sostituisce aws_db_instance RDS)
# Il database viene configurato interamente via user_data (cloud-init)
resource "openstack_compute_instance_v2" "db" {
  name            = "myapp-postgres-db"
  image_id        = data.openstack_images_image_v2.db_image.id
  flavor_id       = data.openstack_compute_flavor_v2.db_flavor.id
  security_groups = [openstack_networking_secgroup_v2.db_sg.name]

  network {
    uuid = openstack_networking_network_v2.main.id
  }

  # Script di installazione e configurazione PostgreSQL
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Installazione PostgreSQL
    apt-get update -y
    apt-get install -y postgresql postgresql-contrib

    # Configurazione per accettare connessioni dalla rete interna
    PG_CONF=$(find /etc/postgresql -name postgresql.conf | head -1)
    PG_HBA=$(find /etc/postgresql -name pg_hba.conf | head -1)

    # Ascolto su tutte le interfacce (non solo localhost)
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

    # Permetti connessioni dalla subnet delle istanze compute
    echo "host    all    all    10.0.0.0/16    md5" >> "$PG_HBA"

    # Riavvio per applicare la configurazione
    systemctl restart postgresql

    # Creazione database, utente e caricamento schema
    sudo -u postgres psql -c "CREATE USER ${var.db_user} WITH PASSWORD '${var.db_password}';"
    sudo -u postgres psql -c "CREATE DATABASE ${var.db_name} OWNER ${var.db_user};"

    # Lo schema viene caricato separatamente via provisioner (vedi null_resource sotto)
    EOF

  depends_on = [
    openstack_networking_subnet_v2.private_1
  ]
}

# Popolamento schema DB (equivalente del null_resource AWS)
resource "null_resource" "db_setup" {
  triggers = {
    schema_hash = filemd5("${path.module}/../terraform_content/schema.sql")
    db_instance = openstack_compute_instance_v2.db.id
  }

  depends_on = [openstack_compute_instance_v2.db]

  provisioner "local-exec" {
    environment = {
      PGPASSWORD = var.db_password
    }

    # Attendiamo che PostgreSQL sia pronto, poi carichiamo lo schema
    command = "sleep 30 && psql -h ${openstack_compute_instance_v2.db.access_ip_v4} -p 5432 -U ${var.db_user} -d ${var.db_name} -f ${path.module}/../terraform_content/schema.sql"
  }
}

# --- OUTPUTS ---

output "swift_frontend_container" {
  description = "Nome del container Swift per il frontend"
  value       = openstack_objectstorage_container_v1.frontend.name
}

output "swift_frontend_url" {
  description = "URL base del container Swift frontend (staticweb)"
  value       = "${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.frontend.name}"
}

output "swift_media_container" {
  description = "Nome del container Swift per i media"
  value       = openstack_objectstorage_container_v1.media.name
}

output "swift_media_url" {
  description = "URL base del container Swift media"
  value       = "${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.media.name}"
}

output "db_host" {
  description = "Indirizzo IP della VM database PostgreSQL"
  value       = openstack_compute_instance_v2.db.access_ip_v4
}

output "db_port" {
  description = "Porta di connessione PostgreSQL"
  value       = "5432"
}

output "db_name" {
  description = "Nome del database PostgreSQL"
  value       = var.db_name
}

output "db_user" {
  description = "Utente del database PostgreSQL"
  value       = var.db_user
}

/*
Questo file gestisce due domini: l'object storage (Swift) e il database (PostgreSQL su VM).

Per lo storage, i bucket S3 diventano container Swift. Il container frontend usa
le ACL Swift (.r:*,.rlistings) per rendere il contenuto pubblicamente leggibile,
equivalente della aws_s3_bucket_policy con Principal = "*". I metadati Web-Index
e Web-Error abilitano il middleware staticweb di Swift, che fornisce funzionalità
simili all'S3 Website Hosting (serve index.html come pagina predefinita e gestisce
gli errori reindirizzandoli, utile per le SPA).

Il container media resta privato (nessuna ACL pubblica), come nell'originale AWS.
L'accesso sarà gestito dal backend tramite credenziali Keystone o tempurl.

Per il database, senza Trove (DBaaS), utilizziamo una VM Nova con PostgreSQL
installato via cloud-init (user_data). Lo script configura PostgreSQL per accettare
connessioni dalla rete interna (10.0.0.0/16) e crea il database con le credenziali
specificate nelle variabili. Il provisioner null_resource carica lo schema SQL
con lo stesso meccanismo (filemd5 trigger) dell'originale AWS.

Il sleep è più lungo (30s vs 5s) perché la VM deve avviarsi, installare PostgreSQL
e configurarlo prima che psql possa connettersi, a differenza di RDS che è un
servizio gestito già pronto.
*/
