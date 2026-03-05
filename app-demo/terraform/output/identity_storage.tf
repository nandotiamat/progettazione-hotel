resource "openstack_identity_role_v3" "media_reader" {
  name = "media_reader"
}

resource "openstack_identity_role_v3" "media_uploader" {
  name = "media_uploader"
}

resource "random_password" "app_frontend_reader_password" {
  length  = var.keystone_default_password_length
  special = true
}

resource "random_password" "app_frontend_uploader_password" {
  length  = var.keystone_default_password_length
  special = true
}

resource "openstack_identity_user_v3" "app_frontend_reader" {
  name     = "app_frontend_reader"
  password = random_password.app_frontend_reader_password.result
  enabled  = true
}

resource "openstack_identity_user_v3" "app_frontend_uploader" {
  name     = "app_frontend_uploader"
  password = random_password.app_frontend_uploader_password.result
  enabled  = true
}

data "openstack_identity_project_v3" "current" {
  name = var.keystone_project_name
}

resource "openstack_identity_role_assignment_v3" "reader" {
  project_id = data.openstack_identity_project_v3.current.id
  user_id    = openstack_identity_user_v3.app_frontend_reader.id
  role_id    = openstack_identity_role_v3.media_reader.id
}

resource "openstack_identity_role_assignment_v3" "uploader" {
  project_id = data.openstack_identity_project_v3.current.id
  user_id    = openstack_identity_user_v3.app_frontend_uploader.id
  role_id    = openstack_identity_role_v3.media_uploader.id
}

resource "openstack_objectstorage_container_v1" "assets" {
  name          = "hotel-assets"
  force_destroy = true

  container_read  = "${data.openstack_identity_project_v3.current.id}:${openstack_identity_user_v3.app_frontend_reader.name},${data.openstack_identity_project_v3.current.id}:${openstack_identity_user_v3.app_frontend_uploader.name}"
  container_write = "${data.openstack_identity_project_v3.current.id}:${openstack_identity_user_v3.app_frontend_uploader.name}"

  depends_on = [
    openstack_identity_role_assignment_v3.reader,
    openstack_identity_role_assignment_v3.uploader,
  ]
}
