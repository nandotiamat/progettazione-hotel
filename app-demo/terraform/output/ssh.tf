resource "tls_private_key" "hotel" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "hotel" {
  name       = "hotel-keypair"
  public_key = tls_private_key.hotel.public_key_openssh
}

resource "local_file" "hotel_private_key" {
  filename        = pathexpand(var.ssh_private_key_path)
  content         = tls_private_key.hotel.private_key_pem
  file_permission = "0600"
}
