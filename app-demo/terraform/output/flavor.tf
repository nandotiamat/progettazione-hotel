resource "openstack_compute_flavor_v2" "hotel_flavor" {
  name      = "hotel_flavor"
  vcpus     = 1
  ram       = 2048
  disk      = 10
  is_public = true
}
