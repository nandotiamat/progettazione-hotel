resource "openstack_compute_keypair_v2" "main_key" {
  name = "main-key"
}

resource "local_file" "private_key" {
  content         = openstack_compute_keypair_v2.main_key.private_key
  filename        = "${path.module}/main-key.pem"
  file_permission = "0600" 
}
