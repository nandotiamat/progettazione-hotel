/* ------------------------------------------------------------------------
   Configurazione principale Terraform per l'infrastruttura OpenStack.
   Definisce i provider richiesti, la configurazione di autenticazione e
   la generazione del file .env con tutti gli output dell'infrastruttura.
   ------------------------------------------------------------------------ */

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# --- PROVIDER OPENSTACK ---
# Autenticazione delegata a clouds.yaml — nessuna credenziale hardcoded
provider "openstack" {
  cloud = var.cloud
}

# --- GENERAZIONE FILE .ENV ---

# File .env con tutti gli output dell'infrastruttura.
# Contiene segreti (password DB, password Keystone) che non devono
# essere esposti come output Terraform.
resource "local_sensitive_file" "dotenv" {
  filename        = var.env_file_path
  file_permission = "0600"

  content = <<-EOF
    # Generato automaticamente da Terraform — non modificare manualmente

    # --- NETWORK ---
    BASTION_FLOATING_IP=${openstack_networking_floatingip_v2.bastion_fip.address}
    LB_FLOATING_IP=${openstack_networking_floatingip_v2.lb_fip.address}

    # --- COMPUTE ---
    FRONTEND_1_IP=${openstack_compute_instance_v2.frontend[0].access_ip_v4}
    FRONTEND_2_IP=${openstack_compute_instance_v2.frontend[1].access_ip_v4}
    BACKEND_IP=${openstack_compute_instance_v2.backend.access_ip_v4}
    DATABASE_IP=${openstack_compute_instance_v2.database.access_ip_v4}
    BASTION_IP=${openstack_compute_instance_v2.bastion.access_ip_v4}

    # --- DATABASE ---
    DB_HOST=${openstack_compute_instance_v2.database.access_ip_v4}
    DB_PORT=5432
    DB_USER=${var.db_user}
    DB_PASS=${var.db_password}
    DB_NAME=${var.db_name}

    # --- SWIFT ---
    SWIFT_CONTAINER=${openstack_objectstorage_container_v1.hotel_assets.name}
    SWIFT_READER_USER=${openstack_identity_user_v3.app_frontend_reader.name}
    SWIFT_READER_PASS=${random_password.reader_password.result}
    SWIFT_UPLOADER_USER=${openstack_identity_user_v3.app_frontend_uploader.name}
    SWIFT_UPLOADER_PASS=${random_password.uploader_password.result}

    # --- LOAD BALANCER ---
    LB_VIP_ADDRESS=${openstack_lb_loadbalancer_v2.hotel_lb.vip_address}

    # --- SSH ---
    SSH_KEY_PATH=${var.keypair_private_key_path}
  EOF
}
