/* ------------------------------------------------------------------------
   Storage e identita': Swift container per i media, utenti e ruoli
   Keystone per l'accesso granulare, e seed delle immagini.
   ------------------------------------------------------------------------ */

# --- PASSWORD GENERATE ---

# Password casuale per l'utente reader di Swift
resource "random_password" "reader_password" {
  length  = 24
  special = false
}

# Password casuale per l'utente uploader di Swift
resource "random_password" "uploader_password" {
  length  = 24
  special = false
}

# --- DATA SOURCE: PROGETTO CORRENTE ---

# Recupera il progetto corrente dall'autenticazione clouds.yaml
data "openstack_identity_project_v3" "current" {
  name = "admin"
}

# --- RUOLI KEYSTONE ---

# Ruolo custom per la lettura dei media dal container Swift
resource "openstack_identity_role_v3" "media_reader" {
  name = "media_reader"
}

# Ruolo custom per l'upload dei media nel container Swift
resource "openstack_identity_role_v3" "media_uploader" {
  name = "media_uploader"
}

# --- UTENTI KEYSTONE ---

# Utente per la lettura dei media (usato dal frontend)
resource "openstack_identity_user_v3" "app_frontend_reader" {
  name               = "app_frontend_reader"
  default_project_id = data.openstack_identity_project_v3.current.id
  password           = random_password.reader_password.result
}

# Utente per l'upload dei media (usato dal frontend)
resource "openstack_identity_user_v3" "app_frontend_uploader" {
  name               = "app_frontend_uploader"
  default_project_id = data.openstack_identity_project_v3.current.id
  password           = random_password.uploader_password.result
}

# --- ASSEGNAZIONE RUOLI ---

# Assegna il ruolo media_reader all'utente reader sul progetto corrente
resource "openstack_identity_role_assignment_v3" "reader_assignment" {
  role_id    = openstack_identity_role_v3.media_reader.id
  user_id    = openstack_identity_user_v3.app_frontend_reader.id
  project_id = data.openstack_identity_project_v3.current.id
}

# Assegna il ruolo media_uploader all'utente uploader sul progetto corrente
resource "openstack_identity_role_assignment_v3" "uploader_assignment" {
  role_id    = openstack_identity_role_v3.media_uploader.id
  user_id    = openstack_identity_user_v3.app_frontend_uploader.id
  project_id = data.openstack_identity_project_v3.current.id
}

# --- SWIFT CONTAINER ---

resource "openstack_objectstorage_container_v1" "hotel_assets" {
  name = var.swift_container_name

  # ACL di lettura: ogni utente con ruolo 'media_reader' o 'media_uploader' può leggere/elencare
  # Nota: includiamo l'uploader nel read_acl così può vedere cosa carica
  container_read = "${openstack_identity_role_v3.media_reader.name}, ${openstack_identity_role_v3.media_uploader.name}"

  # ACL di scrittura: ogni utente con ruolo 'media_uploader' può caricare/eliminare
  container_write = "${openstack_identity_role_v3.media_uploader.name}"
}

# --- SEED MEDIA ---

# Mappa dei file media da caricare nel container Swift
locals {
  media_files = {
    "prop01/front.png"    = "${path.module}/seed_media/prop01_front.png"
    "prop02/front.png"    = "${path.module}/seed_media/prop02_front.png"
    "prop03/front.png"    = "${path.module}/seed_media/prop03_front.png"
    "prop03/interior.png" = "${path.module}/seed_media/prop03_interior.png"
    "prop03/hall.png"     = "${path.module}/seed_media/prop03_hall.png"
    "prop04/front.png"    = "${path.module}/seed_media/prop04_front.png"
    "prop05/front.png"    = "${path.module}/seed_media/prop05_front.png"
    "prop06/front.png"    = "${path.module}/seed_media/prop06_front.png"
    "prop07/front.png"    = "${path.module}/seed_media/prop07_front.png"
    "prop07/hall.png"     = "${path.module}/seed_media/prop07_hall.png"
    "prop07/interior.png" = "${path.module}/seed_media/prop07_interior.png"
    "prop08/front.png"    = "${path.module}/seed_media/prop08_front.png"
    "prop08/hall.png"     = "${path.module}/seed_media/prop08_hall.png"
    "prop09/front.png"    = "${path.module}/seed_media/prop09_front.png"
    "prop09/pool.png"     = "${path.module}/seed_media/prop09_pool.png"
    "prop10/front.png"    = "${path.module}/seed_media/prop10_front.png"
    "prop10/hall.png"     = "${path.module}/seed_media/prop10_hall.png"
  }
}

# Upload dei file media nel container Swift
resource "openstack_objectstorage_object_v1" "media_seed" {
  for_each = local.media_files

  container_name = openstack_objectstorage_container_v1.hotel_assets.name
  name           = each.key
  source         = each.value

  content_type = lookup(
    {
      "png"  = "image/png"
      "jpg"  = "image/jpeg"
      "jpeg" = "image/jpeg"
    },
    split(".", each.key)[length(split(".", each.key)) - 1],
    "application/octet-stream"
  )
}

# --- OUTPUTS ---

output "swift_container_name" {
  description = "Nome del container Swift per i media"
  value       = openstack_objectstorage_container_v1.hotel_assets.name
}

output "keystone_reader_user" {
  description = "Nome utente Keystone per la lettura dei media"
  value       = openstack_identity_user_v3.app_frontend_reader.name
}

output "keystone_uploader_user" {
  description = "Nome utente Keystone per l'upload dei media"
  value       = openstack_identity_user_v3.app_frontend_uploader.name
}
