/* ------------------------------------------------------------------------
   Configurazione provider OpenStack e blocco terraform.
   Equivalente del main.tf AWS, adattato per DevStack stable/2025.1.
   Include la generazione del file dotenv con tutti gli output
   dell'infrastruttura per il backend e il frontend.
   ------------------------------------------------------------------------ */

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

# Provider OpenStack configurato per DevStack locale
provider "openstack" {
  auth_url    = var.os_auth_url
  user_name   = var.os_user_name
  password    = var.os_password
  tenant_name = var.os_tenant_name
  region      = var.os_region
}

# --- FILE GENERATION ---

resource "local_file" "dotenv" {
  filename = "/config/openstack.env"
  content  = <<EOF
# File generato automaticamente da Terraform per OpenStack (DevStack)

# --- AUTENTICAZIONE OPENSTACK (Sostituisce Cognito) ---
# Nota: Keystone NON è un sostituto completo di Cognito.
# Il backend deve essere modificato per usare token Keystone anziché JWT Cognito.
OS_AUTH_URL=${var.os_auth_url}
OS_PROJECT_ID=${openstack_identity_project_v3.app_project.id}
OS_REGION=${var.os_region}
APP_CREDENTIAL_ID=${openstack_identity_application_credential_v3.backend_credential.id}
APP_CREDENTIAL_SECRET=${openstack_identity_application_credential_v3.backend_credential.secret}

# --- LOAD BALANCER (Sostituisce ALB + API Gateway) ---
# In OpenStack non esiste API Gateway. Il LB inoltra direttamente al backend.
# L'autenticazione JWT e il CORS devono essere gestiti a livello applicativo.
LB_VIP_ADDRESS=${openstack_lb_loadbalancer_v2.app_lb.vip_address}
LB_FLOATING_IP=${openstack_networking_floatingip_v2.lb_fip.address}

# --- STORAGE SWIFT (Sostituisce S3) ---
SWIFT_FRONTEND_CONTAINER=${openstack_objectstorage_container_v1.frontend.name}
SWIFT_FRONTEND_URL=${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.frontend.name}
SWIFT_MEDIA_CONTAINER=${openstack_objectstorage_container_v1.media.name}
SWIFT_MEDIA_URL=${var.os_auth_url}/v1/AUTH_${var.os_tenant_name}/${openstack_objectstorage_container_v1.media.name}

# --- DATABASE POSTGRESQL (Sostituisce RDS) ---
DB_HOST=${openstack_compute_instance_v2.db.access_ip_v4}
DB_PORT=5432
DB_USER=${var.db_user}
DB_PASS=${var.db_password}
DB_NAME=${var.db_name}

# --- NOTE SUI SERVIZI MANCANTI ---
# CloudFront: Non disponibile. Il frontend è servito direttamente da Swift (staticweb).
# API Gateway: Non disponibile. Routing e autorizzazione gestiti a livello applicativo.
# Cognito: Mapping parziale su Keystone. Per un IdP completo serve Keycloak.
EOF
}
