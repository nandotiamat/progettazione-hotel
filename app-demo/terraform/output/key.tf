resource "tls_private_key" "hotel_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "app_key" {
  name       = "app-key"
  public_key = tls_private_key.hotel_ssh_key.public_key_openssh
}

resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.hotel_ssh_key.private_key_pem
  filename        = var.keypair_private_key_path
  file_permission = "0600"
}

variable "keypair_private_key_path" {
  description = "Percorso di salvataggio della chiave privata SSH"
  type        = string
  default     = "./.ssh/hotel-key.pem"
}
