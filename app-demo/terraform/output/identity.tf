/* ------------------------------------------------------------------------
   Identity & IAM OpenStack (Keystone).
   Mappatura parziale di Cognito User Pool + Groups + IAM Roles/Policies.
   Keystone NON è un sostituto diretto di Cognito — non supporta
   self-registration, password policies, o JWT token issuance per SPA.
   IAM di AWS è mappato su ruoli Keystone (semplificato).
   Questa sezione fornisce solo una mappatura strutturale.
   ------------------------------------------------------------------------ */

# --- PROGETTO APPLICATIVO ---

# Progetto dedicato all'applicazione (mappatura parziale del User Pool)
resource "openstack_identity_project_v3" "app_project" {
  name        = "myapp-project"
  description = "Progetto applicativo hotel (equivalente strutturale del Cognito User Pool)"
  enabled     = true
}

# --- RUOLO OWNERS ---

# Ruolo per i proprietari di strutture (mappatura del Cognito group OWNERS)
resource "openstack_identity_role_v3" "owners" {
  name = "OWNERS"
}

# --- UTENTE APPLICATIVO (Seed) ---

# Utente di servizio per l'applicazione backend
resource "openstack_identity_user_v3" "app_service_user" {
  name               = "myapp-service"
  default_project_id = openstack_identity_project_v3.app_project.id
  password           = var.db_password
  enabled            = true
  description        = "Utente di servizio per il backend applicativo"
}

# Assegnazione del ruolo OWNERS all'utente di servizio sul progetto
resource "openstack_identity_role_assignment_v3" "service_owner" {
  role_id    = openstack_identity_role_v3.owners.id
  user_id    = openstack_identity_user_v3.app_service_user.id
  project_id = openstack_identity_project_v3.app_project.id
}

# --- IAM: RUOLO BACKEND SERVICE (Sostituisce aws_iam_role + policy) ---

# Ruolo custom per il concetto di "backend service" (equivalente di hotel_backend_role)
# In OpenStack non esistono instance profiles o policy IAM granulari.
# L'accesso a Swift viene gestito tramite credenziali Keystone.
resource "openstack_identity_role_v3" "backend_service" {
  name = "hotel_backend_service"
}

# Assegnazione del ruolo backend_service all'utente di servizio
# Questo permette all'utente di operare sulle risorse del progetto
resource "openstack_identity_role_assignment_v3" "backend_service_role" {
  role_id    = openstack_identity_role_v3.backend_service.id
  user_id    = openstack_identity_user_v3.app_service_user.id
  project_id = openstack_identity_project_v3.app_project.id
}

# --- OUTPUTS ---

output "keystone_project_id" {
  description = "ID del progetto Keystone applicativo"
  value       = openstack_identity_project_v3.app_project.id
}

output "keystone_auth_url" {
  description = "URL di autenticazione Keystone (sostituisce Cognito issuer URL)"
  value       = var.os_auth_url
}

output "keystone_owners_role_id" {
  description = "ID del ruolo OWNERS (equivalente del Cognito group)"
  value       = openstack_identity_role_v3.owners.id
}

output "keystone_backend_role_id" {
  description = "ID del ruolo backend service (equivalente di hotel_backend_role IAM)"
  value       = openstack_identity_role_v3.backend_service.id
}

/*
Questo file fornisce una mappatura strutturale di Cognito verso Keystone.

IMPORTANTE: Keystone NON è un sostituto diretto di Cognito. Le differenze chiave:
- Nessun User Pool con self-registration e password policies
- Nessuna emissione di JWT token per applicazioni frontend (SPA)
- Nessun protocollo SRP per autenticazione sicura lato browser
- Nessun concetto di "Client App" con token validity configurabile

Il progetto Keystone (openstack_identity_project_v3) è il contenitore logico
più vicino al concetto di User Pool, ma opera a livello infrastruttura, non applicazione.

Il ruolo OWNERS mappa il gruppo Cognito "OWNERS" ma in Keystone i ruoli sono
assegnati a livello progetto/dominio, non come attributi dell'utente nei token.

Per un'applicazione reale, l'adattamento richiederebbe:
1. Modificare il backend per usare token Keystone invece di JWT Cognito
2. Implementare un layer di autenticazione custom per il frontend
3. Gestire la registrazione utenti tramite l'applicazione stessa

Il Cognito User Pool Domain e il Client non hanno equivalente in Keystone.

La sezione IAM mappa aws_iam_role, aws_iam_policy e aws_iam_instance_profile su
ruoli Keystone. OpenStack non ha il concetto di:
- Policy IAM granulari (permessi specifici per azioni S3)
- Instance Profiles (ruoli assunti automaticamente dalle VM)
- Assume Role Policy (trust relationships)

L'accesso delle istanze compute a Swift è gestito tramite credenziali Keystone
(username/password o application credentials) piuttosto che tramite ruoli
assunti automaticamente. Il ruolo hotel_backend_service è un marker concettuale
che indica quali utenti hanno diritto di operare come servizio backend.
*/
