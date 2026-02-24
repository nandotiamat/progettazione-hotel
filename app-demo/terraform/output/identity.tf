/* ------------------------------------------------------------------------
   Identity & Access Management OpenStack (Keystone).
   Questo file unisce i domini identity.tf (Cognito) e iam.tf (IAM) dell'originale AWS.

   Mappatura:
   - Cognito User Pool → Progetto Keystone + utenti (mapping parziale)
   - Cognito User Group "OWNERS" → Ruolo Keystone "owners"
   - IAM Role + Policy + Instance Profile → Application Credential Keystone

   IMPORTANTE: Keystone NON è un sostituto completo di Cognito.
   Non supporta: self-registration, password policies frontend, JWT token per SPA,
   OAuth2/OIDC flows nativi. Il backend dell'applicazione dovrà essere modificato
   per usare token Keystone anziché JWT Cognito. Per un equivalente completo,
   sarebbe necessario Keycloak o un altro IdP esterno.
   ------------------------------------------------------------------------ */

# --- PROGETTO APPLICAZIONE (Mapping parziale del User Pool Cognito) ---

# Progetto dedicato per l'applicazione hotel
# In Keystone, un "progetto" è il contenitore logico per risorse e utenti,
# simile concettualmente a un User Pool Cognito (ma con funzionalità diverse)
resource "openstack_identity_project_v3" "app_project" {
  name        = "myapp-hotel"
  description = "Progetto per l'applicazione hotel"
}

# --- RUOLI (Mapping dei Cognito User Groups e IAM Roles) ---

# Ruolo "owners" — equivalente del gruppo Cognito "OWNERS"
# In Keystone i ruoli sostituiscono sia i gruppi Cognito che i ruoli IAM
resource "openstack_identity_role_v3" "owners" {
  name = "owners"
}

# Ruolo per il backend — equivalente dell'IAM Role "hotel_backend_role"
# Questo ruolo viene assegnato alle credenziali usate dalle istanze compute
# per accedere a Swift (equivalente della policy S3 sull'instance profile)
resource "openstack_identity_role_v3" "backend_service" {
  name = "backend_service"
}

# --- APPLICATION CREDENTIAL (Sostituzione IAM Instance Profile) ---

# L'application credential sostituisce l'IAM Instance Profile + Role + Policy.
# Le istanze compute useranno queste credenziali per autenticarsi con Keystone
# e accedere a Swift (object storage), senza esporre le credenziali admin.
#
# A differenza dell'IAM Instance Profile che viene automaticamente iniettato
# nell'istanza EC2 via metadata service, qui le credenziali devono essere
# passate esplicitamente alla VM (via user_data o config drive).
resource "openstack_identity_application_credential_v3" "backend_credential" {
  name        = "hotel-backend-credential"
  description = "Credenziali per le istanze backend (accesso Swift)"
}

# --- ASSEGNAZIONE RUOLI ---

# Assegna il ruolo backend_service al progetto applicazione
# Questo è l'equivalente dell'aws_iam_role_policy_attachment
resource "openstack_identity_role_assignment_v3" "backend_role_assignment" {
  role_id    = openstack_identity_role_v3.backend_service.id
  project_id = openstack_identity_project_v3.app_project.id
  user_id    = data.openstack_identity_user_v3.admin.id
}

# Data source per l'utente admin corrente
data "openstack_identity_user_v3" "admin" {
  name = var.os_user_name
}

# --- NOTA: SERVIZI NON REPLICABILI ---
# Le seguenti funzionalità Cognito NON hanno equivalente in Keystone:
# - aws_cognito_user_pool: self-registration, password policy, email verification
# - aws_cognito_user_pool_client: OAuth2 client con SRP auth, token validity
# - aws_cognito_user_pool_domain: hosted login page
# Per un sostituto completo servirebbe Keycloak o un IdP esterno con OIDC.

# Le seguenti funzionalità IAM NON hanno equivalente in Keystone:
# - Fine-grained policies (accesso per-bucket/per-azione su S3)
# - Trust policies (chi può assumere un ruolo)
# - Instance profiles (credenziali automatiche via metadata service)
# In OpenStack i permessi sono a livello di progetto, non di risorsa singola.

# --- OUTPUTS ---

output "app_project_id" {
  description = "ID del progetto Keystone per l'applicazione"
  value       = openstack_identity_project_v3.app_project.id
}

output "auth_url" {
  description = "URL di autenticazione Keystone (sostituisce Cognito issuer URL)"
  value       = var.os_auth_url
}

output "backend_credential_id" {
  description = "ID dell'application credential per il backend"
  value       = openstack_identity_application_credential_v3.backend_credential.id
}

output "backend_credential_secret" {
  description = "Secret dell'application credential per il backend"
  value       = openstack_identity_application_credential_v3.backend_credential.secret
  sensitive   = true
}

output "owners_role_id" {
  description = "ID del ruolo 'owners' (equivalente del gruppo Cognito OWNERS)"
  value       = openstack_identity_role_v3.owners.id
}

/*
Questo file rappresenta il mapping più complesso dell'intera migrazione perché
combina due servizi AWS (Cognito e IAM) in un unico servizio OpenStack (Keystone)
che ha un modello di sicurezza fondamentalmente diverso.

In AWS, Cognito gestisce l'identità degli utenti finali (frontend) mentre IAM
gestisce i permessi dei servizi infrastrutturali (backend). In OpenStack, Keystone
fa entrambe le cose ma con granularità molto diversa:

- Cognito → Keystone: il mapping è solo strutturale. Un progetto Keystone NON
  è un User Pool con self-registration. Keystone gestisce utenti infrastrutturali,
  non utenti applicativi. Per replicare Cognito servirebbe Keycloak.

- IAM → Keystone: l'application_credential è il sostituto più vicino all'instance
  profile. Fornisce credenziali scoped a un progetto che le VM possono usare per
  autenticarsi con i servizi OpenStack (Swift, etc.). La differenza principale è
  che non sono iniettate automaticamente via metadata service — vanno passate
  esplicitamente alle VM.

- I ruoli Keystone operano a livello di progetto, non di risorsa. Non è possibile
  creare una policy che limiti l'accesso a un singolo container Swift (equivalente
  del bucket S3). L'accesso fine-grained va gestito con Swift ACL o a livello applicativo.
*/
