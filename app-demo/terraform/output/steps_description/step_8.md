# Step 8: Identity (`identity.tf`)

## Goal

Creare le risorse Keystone che mappano (parzialmente) le funzionalità di Cognito (identity provider per utenti) e IAM (permessi per servizi), unificandole in un unico file poiché in OpenStack entrambi i domini sono gestiti da Keystone.

## Rationale

- **Unione di `identity.tf` + `iam.tf`** in un singolo file: in OpenStack non c'è separazione tra identity provider e access management — Keystone gestisce entrambi. Mantenerli separati creerebbe una divisione artificiale senza giustificazione tecnica.
- **`openstack_identity_project_v3`** come mapping strutturale del User Pool: un progetto Keystone è il contenitore logico più vicino a un User Pool, anche se funzionalmente molto diverso (nessuna self-registration, nessun OAuth2 flow).
- **`openstack_identity_role_v3` "owners"** mappa il gruppo Cognito "OWNERS". In Keystone i ruoli sostituiscono i gruppi perché non esiste il concetto di "user group" nello stesso senso di Cognito.
- **`openstack_identity_application_credential_v3`** sostituisce il pattern IAM Role + Policy + Instance Profile. È il meccanismo standard OpenStack per dare credenziali scoped alle applicazioni senza esporre le credenziali admin.
- **Output `sensitive = true`** per il secret dell'application credential, per evitare che venga stampato in chiaro nei log di Terraform.

## Alternatives

1. **Usare Keycloak** come IdP esterno per replicare completamente Cognito (self-registration, JWT, OAuth2/OIDC). Scartato perché richiederebbe un'infrastruttura aggiuntiva (VM o container Keycloak) e configurazione federata con Keystone, fuori scope per questa migrazione infrastrutturale.

2. **Creare utenti Keystone individuali** per simulare gli utenti del User Pool Cognito. Scartato perché Keystone non è progettato per gestire utenti applicativi — è un servizio di identity per operatori infrastrutturali.

3. **Usare `openstack_identity_ec2_credentials_v3`** anziché application credentials. Scartato perché le EC2 credentials sono un meccanismo di compatibilità legacy AWS, non il pattern raccomandato per applicazioni moderne OpenStack.

4. **Omettere completamente il file** dato che Keystone non è un sostituto reale. Mantenuto per documentare il mapping strutturale e fornire le risorse base (progetto, ruoli, credenziali) che il backend OpenStack utilizzerà.
