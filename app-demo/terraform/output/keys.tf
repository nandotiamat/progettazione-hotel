resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = pathexpand("~/.ssh/hotel-key")
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${path.module}/keys/hotel-key.pub"
  file_permission = "0644"
}

resource "openstack_compute_keypair_v2" "hotel_keypair" {
  name       = "hotel-keypair"
  public_key = tls_private_key.ssh_key.public_key_openssh
}
