/* ------------------------------------------------------------------------
   Provider OpenStack e configurazione base.
   Sostituisce il provider AWS/LocalStack con OpenStack targeting DevStack.
   ------------------------------------------------------------------------ */

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# Configurazione provider OpenStack (DevStack)
provider "openstack" {
  auth_url    = var.os_auth_url
  user_name   = var.os_user_name
  password    = var.os_password
  tenant_name = var.os_tenant_name
  region      = var.os_region

  # DevStack con certificati self-signed
  insecure = true
}

# --- FILE GENERATION ---

resource "local_file" "dotenv" {
  filename = "${path.module}/config/openstack.env"
  content  = <<EOF
# File generato automaticamente da Terraform per OpenStack/DevStack

# --- OPENSTACK AUTH ---
OS_AUTH_URL=${var.os_auth_url}
OS_REGION=${var.os_region}
OS_PROJECT_ID=${openstack_identity_project_v3.app_project.id}
OS_PROJECT_NAME=${openstack_identity_project_v3.app_project.name}
OS_USER_NAME=${openstack_identity_user_v3.app_service_user.name}

# --- LOAD BALANCER ---
LB_VIP_ADDRESS=${openstack_lb_loadbalancer_v2.app_lb.vip_address}

# --- SWIFT STORAGE ---
SWIFT_FRONTEND_CONTAINER=${openstack_objectstorage_container_v1.frontend.name}
SWIFT_MEDIA_CONTAINER=${openstack_objectstorage_container_v1.media.name}
SWIFT_FRONTEND_URL=${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.frontend.name}
SWIFT_MEDIA_URL=${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.media.name}

# --- DATABASE ---
DB_HOST=${openstack_compute_instance_v2.db_server.access_ip_v4}
DB_PORT=5432
DB_USER=dbadmin
DB_PASS=${var.db_password}
DB_NAME=myappdb

# --- NETWORKING ---
NETWORK_ID=${openstack_networking_network_v2.main.id}
ROUTER_ID=${openstack_networking_router_v2.main.id}
EOF
}
