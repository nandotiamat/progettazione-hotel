# output/compute.tf
resource "openstack_compute_keypair_v2" "app_key" {
  name       = "app-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE9N92qV0mIom1V5oZlZg2iWjI8Oq6H5JqH5w8M1Jd+x5g/rN/4Qe39R1Xy5Gv6Y4f2n2/3s6U6HhE7C+R+YVf/B1mI7h/X4T+E2b5z1Q8T0A2E2A/T6X7A/C5b6Q9K5A+X3L3K2H5R+N9X8W/z1A4A/Q+T8E5Q/Q/B5V+X9L9V/Q8T+Q2H2A/T6H+R9A+R/N9A/B5V/E/Q5T/T+H/Q+A="
}

data "openstack_images_image_v2" "cirros" {
  name        = "cirros-0.5.2-x86_64-disk"
  most_recent = true
}

resource "openstack_compute_instance_v2" "app_instance" {
  count           = 2
  name            = "app-instance-${count.index}"
  image_id        = data.openstack_images_image_v2.cirros.id
  flavor_name     = "m1.nano"
  key_pair        = openstack_compute_keypair_v2.app_key.name
  security_groups = [openstack_networking_secgroup_v2.app_sg.name]

  network {
    uuid = openstack_networking_network_v2.app_net.id
  }
}
