resource "openstack_compute_flavor_v2" "hotel_flavor" {
  name      = var.flavor_name
  ram       = 2048
  vcpus     = 1
  disk      = 10
  is_public = true
}
