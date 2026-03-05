# output/storage.tf
resource "openstack_objectstorage_container_v1" "app_bucket" {
  region = var.os_region
  name   = "app-assets"

  # Swift public access equivalent
  container_read = ".r:*,.rlistings"
}
