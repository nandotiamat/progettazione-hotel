resource "openstack_objectstorage_container_v1" "frontend" {
  name = "${var.app_name}-frontend"
}

resource "openstack_objectstorage_container_v1" "media" {
  name = "${var.app_name}-media"
}
