# --- Images & Flavors (Glance & Nova) ---

resource "openstack_compute_flavor_v2" "hotel_flavor" {
  name      = "hotel_flavor"
  ram       = "2048"
  vcpus     = "1"
  disk      = "10"
  is_public = true
}

resource "openstack_images_image_v2" "ubuntu_image" {
  name             = "ubuntu-jammy"
  image_source_url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  container_format = "bare"
  disk_format      = "qcow2"

  properties = {
    os_type = "linux"
  }
}

data "openstack_images_image_v2" "cirros" {
  name        = "cirros-0.6.3-x86_64-disk"
  most_recent = true
}
