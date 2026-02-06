resource "openstack_compute_keypair_v2" "hotel_key" {
  name = "hotel-key"
}

# Save the private key to a local file for SSH access
resource "local_file" "private_key" {
  content         = openstack_compute_keypair_v2.hotel_key.private_key
  filename        = "${path.module}/hotel-key.pem"
  file_permission = "0600"
}
