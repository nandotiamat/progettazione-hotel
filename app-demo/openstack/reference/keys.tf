resource "openstack_compute_keypair_v2" "hotel_keypair" {
  name       = "hotel-keypair"
  public_key = file(var.ssh_public_key_path)
}
