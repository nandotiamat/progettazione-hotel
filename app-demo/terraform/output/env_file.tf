locals {
  env_file_contents = join("\n", [
    "APP_NAME=${var.app_name}",
    "LB_HTTP_ENDPOINT=http://${openstack_networking_floatingip_v2.lb.address}:${var.lb_listen_port}",
    "BACKEND_PORT=${var.backend_app_port}",
    "DB_HOST=${local.db_fixed_ipv4}",
    "DB_PORT=${var.db_port}",
    "DB_NAME=${var.db_name}",
    "DB_USER=${var.db_user}",
    "DB_PASSWORD=${local.effective_db_password}",
    "SWIFT_FRONTEND_CONTAINER=${openstack_objectstorage_container_v1.frontend.name}",
    "SWIFT_MEDIA_CONTAINER=${openstack_objectstorage_container_v1.media.name}",
    "",
  ])
}

resource "local_file" "env" {
  filename = var.env_file_path
  content  = local.env_file_contents
}
