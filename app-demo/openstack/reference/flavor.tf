resource "openstack_compute_flavor_v2" "hotel_flavor" {
  name      = var.hotel_flavor
  ram       = 2048
  vcpus     = 1
  disk      = 10
  is_public = true
}
