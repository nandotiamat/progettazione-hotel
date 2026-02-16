resource "openstack_compute_instance_v2" "debug_node" {
  name            = "debug-node"
  image_name      = var.image_name
  flavor_id       = openstack_compute_flavor_v2.hotel_optimized.id
  config_drive    = true
  security_groups = [openstack_networking_secgroup_v2.sg_debug.name]

  network {
    uuid = openstack_networking_network_v2.debug_net.id
  }

  user_data = <<-EOF
    #cloud-config
    password: password123
    chpasswd: { expire: False }
    ssh_pwauth: True
  EOF
}
