resource "openstack_images_image_v2" "ubuntu_jammy" {
  name             = "hotel-ubuntu-jammy"
  container_format = "bare"
  disk_format      = "qcow2"

  image_source_url = var.jammy_image_source_url

  visibility = "private"
  tags       = ["hotel", "ubuntu", "jammy"]
}

data "openstack_images_image_v2" "cirros" {
  name        = var.cirros_image_name
  most_recent = true
}
