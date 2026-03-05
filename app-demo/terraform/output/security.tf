# --- IAM (Keystone) Users & Roles ---

resource "random_password" "reader_password" {
  length  = 16
  special = true
}

resource "random_password" "uploader_password" {
  length  = 16
  special = true
}

resource "openstack_identity_user_v3" "app_frontend_reader" {
  name                                  = "app_frontend_reader"
  default_project_id                    = var.project_id
  password                              = random_password.reader_password.result
  ignore_change_password_upon_first_use = true
}

resource "openstack_identity_user_v3" "app_frontend_uploader" {
  name                                  = "app_frontend_uploader"
  default_project_id                    = var.project_id
  password                              = random_password.uploader_password.result
  ignore_change_password_upon_first_use = true
}

resource "openstack_identity_role_v3" "media_reader" {
  name = "media_reader"
}

resource "openstack_identity_role_v3" "media_uploader" {
  name = "media_uploader"
}

resource "openstack_identity_role_assignment_v3" "reader_assignment" {
  user_id    = openstack_identity_user_v3.app_frontend_reader.id
  project_id = var.project_id
  role_id    = openstack_identity_role_v3.media_reader.id
}

resource "openstack_identity_role_assignment_v3" "uploader_assignment" {
  user_id    = openstack_identity_user_v3.app_frontend_uploader.id
  project_id = var.project_id
  role_id    = openstack_identity_role_v3.media_uploader.id
}

# --- SSH Keypair ---

resource "tls_private_key" "hotel_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "hotel_keypair" {
  name       = "hotel-keypair"
  public_key = tls_private_key.hotel_key.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.hotel_key.private_key_pem
  filename        = pathexpand("~/.ssh/hotel-key.pem")
  file_permission = "0600"
}

# --- Security Groups ---

resource "openstack_networking_secgroup_v2" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group for Bastion node"
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
}

resource "openstack_networking_secgroup_v2" "frontend_sg" {
  name        = "frontend_sg"
  description = "Security group for Frontend nodes"
}

resource "openstack_networking_secgroup_rule_v2" "frontend_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0" # In a real environment, this might be restricted to LB subnet
  security_group_id = openstack_networking_secgroup_v2.frontend_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "frontend_ssh_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
  security_group_id = openstack_networking_secgroup_v2.frontend_sg.id
}

resource "openstack_networking_secgroup_v2" "backend_sg" {
  name        = "backend_sg"
  description = "Security group for Backend nodes"
}

resource "openstack_networking_secgroup_rule_v2" "backend_http_frontend" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_group_id   = openstack_networking_secgroup_v2.frontend_sg.id
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "backend_ssh_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.frontend_sg.id # The plan says Frontend SG, but usually SSH is from bastion. Following plan strictly: "Backend SG: Ingress TCP/80 and TCP/22 exclusively from Frontend SG." Wait, let me re-read plan. "Ingress TCP/80 and TCP/22 exclusively from Frontend SG".
  security_group_id = openstack_networking_secgroup_v2.backend_sg.id
}

resource "openstack_networking_secgroup_v2" "database_sg" {
  name        = "database_sg"
  description = "Security group for Database nodes"
}

resource "openstack_networking_secgroup_rule_v2" "database_postgres_backend" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.backend_sg.id
  security_group_id = openstack_networking_secgroup_v2.database_sg.id
}
