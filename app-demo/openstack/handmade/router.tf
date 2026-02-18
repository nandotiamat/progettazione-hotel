data "openstack_networking_network_v2" "public" {
  name = var.external_network_name
}

resource "openstack_networking_router_v2" "main_router" {
  name                = "main-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
}

# Connect the router to our internal subnet
resource "openstack_networking_router_interface_v2" "main_router_interface" {
  router_id = openstack_networking_router_v2.main_router.id
  subnet_id = openstack_networking_subnet_v2.main_subnet.id
}
