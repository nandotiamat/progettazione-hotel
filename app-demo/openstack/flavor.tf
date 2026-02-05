resource "openstack_compute_flavor_v2" "hotel_optimized" {
  name      = "hotel.optimized"
  ram       = 1024
  vcpus     = 1
  disk      = 10
  is_public = true
}
