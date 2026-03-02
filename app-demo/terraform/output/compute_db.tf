resource "random_password" "db" {
  length  = 24
  special = false
}

locals {
  effective_db_password = var.db_password != "" ? var.db_password : random_password.db.result

  db_user_data = templatefile("${path.module}/user_data/db.sh", {
    DB_NAME     = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = local.effective_db_password
    APP_CIDR    = var.network_cidr
  })
}

resource "openstack_compute_instance_v2" "db" {
  name      = "${var.app_name}-db"
  image_id  = data.openstack_images_image_v2.image.id
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = var.keypair_name
  user_data = local.db_user_data

  security_groups = [
    openstack_networking_secgroup_v2.db.name,
  ]

  network {
    uuid = openstack_networking_network_v2.app_net.id
  }
}

locals {
  db_fixed_ipv4 = openstack_compute_instance_v2.db.network[0].fixed_ip_v4
}
