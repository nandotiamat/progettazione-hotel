# --- GATEWAY INSTANCE (Nginx) ---

resource "openstack_compute_instance_v2" "gateway_node" {
  name            = "gateway-node"
  image_name      = var.image_name
  flavor_id       = openstack_compute_flavor_v2.hotel_optimized.id
  key_pair        = var.ssh_key_name
  config_drive    = true
  security_groups = [
    openstack_networking_secgroup_v2.sg_ssh.name,
    openstack_networking_secgroup_v2.sg_web.name, # Public Web Access
    openstack_networking_secgroup_v2.sg_internal.name
  ]

  network {
    uuid = openstack_networking_network_v2.hotel_net.id
  }
  
  # Wait for apps and auth to be known so we can inject their IPs
  depends_on = [
    openstack_compute_instance_v2.app_node,
    openstack_compute_instance_v2.auth_node
  ]

  user_data = templatefile("${path.module}/nginx_setup.sh.tpl", {
    app_ips  = openstack_compute_instance_v2.app_node[*].access_ip_v4
    auth_ip  = openstack_compute_instance_v2.auth_node.access_ip_v4
  })
}

# --- FLOATING IP ---

resource "openstack_networking_floatingip_v2" "gateway_fip" {
  pool = "public" # Adjust based on your DevStack public network name
}

resource "openstack_compute_floatingip_associate_v2" "gateway_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.gateway_fip.address
  instance_id = openstack_compute_instance_v2.gateway_node.id
}
