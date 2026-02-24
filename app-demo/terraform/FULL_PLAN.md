# FULL_PLAN.md — AWS-to-OpenStack Terraform Migration (All Components Available)

## Objective

Translate the existing AWS Terraform scripts (designed for LocalStack) into an equivalent
OpenStack Terraform configuration targeting a DevStack `stable/2025.1` environment,
**assuming the DevStack node already has all required components installed**.

---

## Prerequisite: DevStack `local.conf`

The target DevStack must have these additional plugins enabled beyond the original
`local.conf` provided in PROMPT.md:

```ini
# --- ORCHESTRAZIONE (CloudFormation + ASG) ---
enable_plugin heat https://opendev.org/openstack/heat stable/2025.1

# --- DNS (Route53) ---
enable_plugin designate https://opendev.org/openstack/designate stable/2025.1
enable_service designate,designate-central,designate-api,designate-worker,designate-producer,designate-mdns

# --- GESTIONE SEGRETI (Secrets Manager / KMS / ACM) ---
enable_plugin barbican https://opendev.org/openstack/barbican stable/2025.1

# --- TELEMETRIA + ALLARMI (CloudWatch) ---
CEILOMETER_BACKENDS=gnocchi
enable_plugin ceilometer https://opendev.org/openstack/ceilometer stable/2025.1
enable_plugin aodh https://opendev.org/openstack/aodh stable/2025.1

# --- DATABASE AS A SERVICE (RDS) ---
enable_plugin trove https://opendev.org/openstack/trove stable/2025.1

# --- STATIC WEBSITE HOSTING (S3 Website) ---
SWIFT_EXTRAS_MIDDLEWARE="staticweb"
```

Services already present from the original `local.conf`: Keystone, Nova, Neutron+OVN,
Glance, Cinder, Swift, Octavia (OVN provider), Horizon, Placement.

---

## Complete AWS → OpenStack Service Mapping

| AWS Resource                       | OpenStack Service   | OpenStack Resource(s)                              |
|------------------------------------|---------------------|----------------------------------------------------|
| `aws_vpc`                          | Neutron             | `openstack_networking_network_v2`                  |
| `aws_subnet`                       | Neutron             | `openstack_networking_subnet_v2`                   |
| `aws_internet_gateway`             | Neutron             | `openstack_networking_router_v2` (ext. gateway)    |
| `aws_route_table` + association    | Neutron             | `openstack_networking_router_interface_v2`         |
| `aws_security_group`               | Neutron             | `openstack_networking_secgroup_v2`                 |
| `aws_security_group_rule`          | Neutron             | `openstack_networking_secgroup_rule_v2`            |
| `aws_lb` (ALB)                     | Octavia             | `openstack_lb_loadbalancer_v2`                     |
| `aws_lb_target_group`              | Octavia             | `openstack_lb_pool_v2`                             |
| `aws_lb_listener`                  | Octavia             | `openstack_lb_listener_v2`                         |
| Health check                       | Octavia             | `openstack_lb_monitor_v2`                          |
| LB member registration             | Octavia             | `openstack_lb_member_v2`                           |
| `aws_launch_template` + `aws_autoscaling_group` | Heat  | `openstack_orchestration_stack_v1` (HOT template)  |
| `aws_autoscaling_policy`           | Heat + Aodh         | Defined inside Heat template                       |
| `aws_cloudwatch_metric_alarm`      | Aodh                | Defined inside Heat template                       |
| `aws_instance`                     | Nova                | `openstack_compute_instance_v2`                    |
| `aws_s3_bucket`                    | Swift               | `openstack_objectstorage_container_v1`             |
| `aws_s3_bucket_website_configuration` | Swift staticweb  | Container metadata (`web-index`, `web-error`)      |
| `aws_s3_bucket_policy`             | Swift               | `container_read` ACL (`.r:*,.rlistings`)           |
| `aws_s3_object`                    | Swift               | `openstack_objectstorage_object_v1`                |
| `aws_db_instance` (RDS PostgreSQL) | Trove               | `openstack_db_instance_v1`                         |
| DB schema seeding                  | —                   | `null_resource` + `local-exec` (psql)              |
| `aws_cognito_user_pool`            | Keystone (partial)  | `openstack_identity_project_v3`                    |
| `aws_cognito_user_group`           | Keystone            | `openstack_identity_role_v3`                       |
| `aws_cognito_user_pool_client`     | Keystone            | `openstack_identity_application_credential_v3`     |
| `aws_iam_role`                     | Keystone            | `openstack_identity_role_v3`                       |
| `aws_iam_policy` + attachment      | Keystone            | `openstack_identity_role_assignment_v3`            |
| `aws_iam_instance_profile`         | Keystone            | Application credentials injected via `user_data`   |
| `aws_route53_zone`                 | Designate           | `openstack_dns_zone_v2`                            |
| `aws_route53_record`               | Designate           | `openstack_dns_recordset_v2`                       |
| `aws_apigatewayv2_api` (HTTP)      | **Nessun equiv.**   | Nginx reverse proxy su VM dedicata                 |
| `aws_apigatewayv2_authorizer` (JWT)| **Nessun equiv.**   | Validazione JWT nell'app o in Nginx+Lua            |
| `aws_cloudfront_distribution`      | **Nessun equiv.**   | Swift staticweb diretto (niente CDN)               |

---

## File Structure (Output)

| File                      | Dominio                              | Corrispondenza AWS         |
|---------------------------|--------------------------------------|----------------------------|
| `main.tf`                 | Provider + generazione dotenv        | `main.tf`                  |
| `variables.tf`            | Variabili centralizzate              | `variables.tf`             |
| `network.tf`              | Rete, subnet, router, DNS           | `network.tf`               |
| `security.tf`             | Security groups                      | `security.tf`              |
| `compute.tf`              | LB (Octavia) + ASG (Heat) + debug   | `compute.tf`               |
| `storage.tf`              | Swift containers + Trove DB + seed   | `storage.tf`               |
| `identity.tf`             | Keystone (IAM + Cognito mapping)     | `identity.tf` + `iam.tf`   |
| `gateway.tf`              | Nginx reverse proxy su VM            | `gateway.tf`               |

Note: `frontend_distribution.tf` viene eliminato — la funzionalità CDN è assorbita
da Swift staticweb in `storage.tf`. `iam.tf` viene fuso in `identity.tf`.

---

## Step-by-Step Implementation Plan

### Step 1: `variables.tf` — Variabili di Configurazione

Definire tutte le variabili necessarie per l'ambiente OpenStack DevStack.

| Variabile           | Tipo     | Default                            | Sostituisce           |
|---------------------|----------|------------------------------------|-----------------------|
| `os_auth_url`       | `string` | `"http://192.168.1.13/identity"`   | —                     |
| `os_region`         | `string` | `"RegionOne"`                      | `aws_region`          |
| `os_user_name`      | `string` | `"admin"`                          | —                     |
| `os_password`       | `string` | `"secret"`                         | —                     |
| `os_tenant_name`    | `string` | `"admin"`                          | —                     |
| `db_password`       | `string` | `"test"`                           | `db_password` (uguale)|
| `image_name`        | `string` | `"cirros-0.6.3-x86_64-disk"`      | AMI ID                |
| `flavor_name`       | `string` | `"m1.small"`                       | Instance type         |
| `external_network`  | `string` | `"public"`                         | —                     |
| `dns_zone_name`     | `string` | `"myapp.local."`                   | Route53 zone          |

Tutte le variabili avranno `description`, `type` e `default`.

---

### Step 2: `main.tf` — Provider e Generazione Dotenv

**Provider:**
```
terraform-provider-openstack/openstack ~> 3.0
```

Configurazione:
- `auth_url`, `user_name`, `password`, `tenant_name`, `region` dalle variabili
- Nessun backend remoto (state locale, come l'originale)

**Dotenv (`local_file`):**
Genera il file `/config/openstack.env` con tutti gli output dell'infrastruttura.
Struttura aggiornata per OpenStack:
- Keystone auth URL + project ID (sostituisce Cognito)
- Swift endpoint + nomi container (sostituisce S3)
- Trove/DB endpoint + credenziali (sostituisce RDS endpoint)
- LB VIP address (sostituisce ALB DNS)
- DNS zone name (sostituisce Route53)
- Nginx proxy endpoint (sostituisce API Gateway)
- Swift frontend URL (sostituisce CloudFront)

Il dotenv sarà finalizzato come ultima risorsa dopo che tutti gli output sono disponibili.

---

### Step 3: `network.tf` — Networking

**Risorse da creare:**

1. **`data.openstack_networking_network_v2.external`** — riferimento alla rete esterna
   `public` preesistente in DevStack

2. **`openstack_networking_network_v2.main`** — rete interna principale (equivale a
   `aws_vpc.main`). Una singola rete Neutron con 4 subnet replica il modello VPC.

3. **`openstack_networking_subnet_v2.public_1`** (`10.0.1.0/24`) — subnet pubblica 1
4. **`openstack_networking_subnet_v2.public_2`** (`10.0.2.0/24`) — subnet pubblica 2
5. **`openstack_networking_subnet_v2.private_1`** (`10.0.3.0/24`) — subnet privata 1
6. **`openstack_networking_subnet_v2.private_2`** (`10.0.4.0/24`) — subnet privata 2

7. **`openstack_networking_router_v2.main`** — router connesso alla rete esterna
   `public` (equivale a `aws_internet_gateway` + route table pubblica)

8. **`openstack_networking_router_interface_v2.public_1`** — collega subnet pubblica 1
   al router
9. **`openstack_networking_router_interface_v2.public_2`** — collega subnet pubblica 2
   al router
   
   Le subnet private NON sono collegate al router (nessun NAT — replica il design AWS
   dove non c'è NAT gateway).

10. **`openstack_dns_zone_v2.private`** — zona DNS `myapp.local.` (equivale a
    `aws_route53_zone.private`). Designate la gestisce come zona autoritativa. Non è
    associata a una VPC specifica come in Route53, ma è scoped al progetto Keystone.

**Outputs:** `network_id`, `public_subnet_ids`, `private_subnet_ids`, `router_id`,
`dns_zone_id`

**Note architetturali:**
- In OpenStack non esiste il concetto di "map_public_ip_on_launch". Le floating IP
  vengono assegnate esplicitamente alle porte.
- Il router con gateway esterno gestisce sia il ruolo di Internet Gateway che di
  route table pubblica.
- La subnet privata isolata (senza interfaccia router) non avrà accesso esterno,
  replicando il comportamento AWS senza NAT Gateway.

---

### Step 4: `security.tf` — Security Groups

**Risorse da creare:**

1. **`openstack_networking_secgroup_v2.lb_sg`** — Security group per il Load Balancer
   - Regole ingresso: TCP 80 (HTTP), TCP 443 (HTTPS) da `0.0.0.0/0`
   - OpenStack permette tutto il traffico in uscita di default

2. **`openstack_networking_secgroup_v2.compute_sg`** — Security group per le istanze
   - Regole ingresso:
     - TCP 8000 da `0.0.0.0/0` (debug)
     - TCP 80 dal `lb_sg` (tramite `remote_group_id`)
     - TCP 22 da `10.0.0.0/16` (SSH interno)

3. **`openstack_networking_secgroup_v2.db_sg`** — Security group per il database
   - Regole ingresso: TCP 5432 dal `compute_sg` (tramite `remote_group_id`)

4. **`openstack_networking_secgroup_v2.proxy_sg`** — Security group per il reverse proxy
   (Nginx, equivale al gateway)
   - Regole ingresso: TCP 80, TCP 443 da `0.0.0.0/0`

Ogni security group ha le proprie `openstack_networking_secgroup_rule_v2` create come
risorse separate (non inline) per chiarezza.

**Outputs:** `lb_sg_id`, `compute_sg_id`, `db_sg_id`, `proxy_sg_id`

**Note:**
- In OpenStack, il riferimento tra security groups usa `remote_group_id` anziché
  `security_groups` di AWS. Il concetto è identico.
- OpenStack NON richiede regole di egress esplicite — il traffico in uscita è permesso
  di default. Le includiamo comunque per chiarezza documentale.

---

### Step 5: `storage.tf` — Object Storage (Swift) + Database (Trove)

#### Parte 1: Swift Containers

1. **`openstack_objectstorage_container_v1.frontend`** — container per il frontend
   - Nome: `my-app-frontend-container`
   - `container_read = ".r:*,.rlistings"` (accesso pubblico in lettura)
   - Metadata per staticweb:
     - `web-index = "index.html"`
     - `web-error = "index.html"` (SPA: tutti gli errori servono index.html)

2. **`openstack_objectstorage_container_v1.media`** — container per i media
   - Nome: `my-app-media-assets`
   - Privato (nessun ACL pubblico)

3. **`locals.media_files`** — mappa dei file seed (identica all'originale)

4. **`openstack_objectstorage_object_v1.media_seed`** — upload file seed con
   `for_each` (identico pattern AWS). Ogni oggetto specifica `content_type` basato
   sull'estensione.

#### Parte 2: Trove Database

5. **`openstack_db_instance_v1.postgres`** — istanza Trove PostgreSQL
   - `datastore_type = "postgresql"`
   - `datastore_version` = versione supportata (es. `"12"` per 2025.1)
   - `flavor_id` — flavor piccolo (equivale a `db.t3.micro`)
   - `size` = 20 (GB, disco)
   - `name` = `"myapp-postgres-db"`
   - Rete: collegata alla subnet privata
   - `database`: nome `"myappdb"`
   - `user`: nome `"dbadmin"`, password da variabile

6. **`openstack_db_database_v1.myappdb`** — database dentro l'istanza Trove

7. **`openstack_db_user_v1.dbadmin`** — utente con accesso al database

8. **`null_resource.db_setup`** — esecuzione schema SQL via `psql`, identico pattern
   all'originale. Trigger su `filemd5("schema.sql")` + ID istanza Trove.
   Il comando `psql` punta all'IP dell'istanza Trove sulla porta 5432.

#### Parte 3: DNS Records per Storage

9. **`openstack_dns_recordset_v2.db_record`** — record DNS `db.myapp.local.` che punta
   all'IP dell'istanza Trove (equivale a un eventuale record Route53 per RDS)

**Outputs:** `swift_frontend_url`, `swift_frontend_container`, `swift_media_container`,
`swift_media_url`, `db_endpoint`, `db_name`

**Note:**
- Swift staticweb con metadata `web-index` e `web-error` replica il comportamento di
  `aws_s3_bucket_website_configuration`. Il path per accedere è:
  `http://<host>:8080/v1/AUTH_<project>/my-app-frontend-container/`
- Il `web-error = "index.html"` gestisce il routing SPA (equivale al
  `error_document { key = "index.html" }` di S3 e ai `custom_error_response` di
  CloudFront).
- Trove potrebbe essere lento in ambienti nested — se non funziona, il fallback è una
  VM Nova con PostgreSQL installato via `user_data`.

---

### Step 6: `compute.tf` — Load Balancer (Octavia) + Auto Scaling (Heat) + Debug

#### Parte 1: Load Balancer (Octavia)

1. **`openstack_lb_loadbalancer_v2.app_lb`** — Load Balancer sulla subnet pubblica 1
   - `vip_subnet_id` = subnet pubblica
   - Security group: `lb_sg`

2. **`openstack_lb_listener_v2.http`** — listener HTTP porta 80
   - `protocol = "HTTP"` — nota: Octavia OVN provider supporta solo TCP;
     se HTTP non è disponibile, usiamo `protocol = "TCP"`

3. **`openstack_lb_pool_v2.app_pool`** — pool con algoritmo `ROUND_ROBIN`
   - `protocol = "HTTP"` (o `"TCP"` se OVN-only)

4. **`openstack_lb_monitor_v2.health`** — health monitor
   - `type = "HTTP"` (o `"TCP"`)
   - `url_path = "/"`
   - `expected_codes = "200-499"` (rilassato, come l'originale)
   - `delay = 10`, `timeout = 5`, `max_retries = 2`

5. **`openstack_networking_floatingip_v2.lb_vip`** — floating IP per rendere il LB
   raggiungibile dall'esterno

6. **`openstack_networking_floatingip_associate_v2.lb_vip`** — associa la floating IP
   alla VIP port del LB

#### Parte 2: Auto Scaling Group (Heat)

7. **`openstack_orchestration_stack_v1.asg`** — stack Heat che contiene:

   Il template Heat (HOT) definito come `templatefile()` conterrà:

   - **`OS::Heat::AutoScalingGroup`** — equivale a `aws_autoscaling_group`
     - `min_size: 1`, `max_size: 3`, `desired_capacity: 2`
     - Resource template: `OS::Nova::Server` con:
       - Image, flavor, rete (subnet privata), security group (`compute_sg`)
       - Stesse specifiche del `aws_launch_template`

   - **`OS::Heat::ScalingPolicy`** (`scale_up`) — equivale a `aws_autoscaling_policy`
     - `adjustment_type: change_in_capacity`
     - `scaling_adjustment: 1`
     - `cooldown: 300`

   - **`OS::Octavia::Pool`** + **`OS::Octavia::Member`** — registrazione automatica
     dei membri ASG nel pool Octavia

   - **`OS::Aodh::GnocchiAggregationByResourcesAlarm`** — equivale a
     `aws_cloudwatch_metric_alarm`
     - `metric: cpu_util`
     - `threshold: 70`
     - `comparison_operator: gt`
     - `evaluation_periods: 2`
     - `alarm_actions: [scale_up_policy webhook URL]`

   Il template Heat viene scritto come file `.yaml` separato in `templates/asg.yaml`
   e referenziato via `templatefile()`.

#### Parte 3: Debug Instance

8. **`openstack_compute_instance_v2.debug_node`** — istanza di debug
   - Equivale a `aws_instance.manual_debug_node`
   - Connessa alla subnet pubblica (con floating IP)
   - Security group: compute_sg
   - `user_data`: script che avvia un HTTP server sulla porta 8000

9. **`openstack_networking_floatingip_v2.debug_fip`** — floating IP per il debug node

**Outputs:** `lb_vip_address`, `lb_floating_ip`

**Note sul provider Octavia OVN:**
Il provider OVN per Octavia supporta solo load balancing L4 (TCP/UDP), non L7 (HTTP).
Questo significa:
- Nessun path-based routing (non necessario — l'originale usa solo forward-all)
- Health check potrebbe essere limitato a TCP (non HTTP)
- Il listener usa `protocol = "TCP"` se HTTP non è supportato

Questo è accettabile perché la configurazione AWS originale usa un semplice listener
HTTP che inoltra tutto al target group senza regole L7 avanzate.

**Note su Heat + Aodh:**
Ceilometer raccoglie le metriche → Gnocchi le archivia → Aodh valuta gli allarmi →
Aodh invia webhook a Heat → Heat scala l'ASG. Questo è il pattern canonico OpenStack
per l'auto-scaling, esattamente equivalente a CloudWatch Alarm → ASG Policy in AWS.

---

### Step 7: `identity.tf` — Identità (Keystone = IAM + Cognito parziale)

#### Parte 1: IAM (Ruoli e Permessi)

1. **`openstack_identity_role_v3.backend_role`** — ruolo `hotel_backend`
   - Equivale a `aws_iam_role.backend_role`
   - In OpenStack, i ruoli sono semplici etichette — i permessi effettivi sono
     gestiti dalle policy di ogni servizio (nova policy.json, swift ACL, ecc.)

2. **`openstack_identity_project_v3.app_project`** — progetto dedicato per
   l'applicazione (se si vuole separare dal progetto `admin`)

3. **`openstack_identity_user_v3.backend_user`** — utente di servizio per il backend
   - Questo utente riceverà il ruolo `hotel_backend`
   - Le sue credenziali verranno iniettate nelle istanze compute via `user_data`
     (equivale funzionalmente all'instance profile + IAM role)

4. **`openstack_identity_role_assignment_v3.backend_assignment`** — assegnazione del
   ruolo al utente sul progetto

5. **`openstack_identity_application_credential_v3.backend_cred`** — credenziali
   applicative per il backend
   - Genera una coppia ID/secret che il backend usa per autenticarsi con Keystone
     e accedere a Swift (equivale a IAM instance profile per S3)
   - Più sicuro di username/password hardcoded

#### Parte 2: Cognito (Mapping Parziale)

6. **`openstack_identity_role_v3.owners_role`** — ruolo `OWNERS`
   - Equivale a `aws_cognito_user_group.owners`
   - In Keystone, i "gruppi" Cognito mappano a ruoli

**Cosa NON è replicabile con Keystone:**
- User Pool con self-registration e hosted UI → necessita Keycloak
- Password policy (min length, uppercase, numbers) → Keystone ha policy diverse
- JWT tokens per SPA (access/id/refresh) → Keystone usa Fernet/JWT interni
- Token validity configurabile (60 min access, 1 day refresh) → non equivalente
- `prevent_user_existence_errors` → non applicabile
- User Pool Domain → non applicabile

Il commento nel codice documenterà che per una replica completa di Cognito serve
un IdP esterno (Keycloak, Authentik) federato con Keystone.

**Outputs:** `app_project_id`, `backend_user_id`, `keystone_auth_url`

---

### Step 8: `gateway.tf` — Reverse Proxy (Nginx su VM)

OpenStack non ha un servizio API Gateway gestito. Creiamo un'istanza Nova con Nginx
configurato come reverse proxy, replicando le funzionalità essenziali del gateway API.

**Risorse da creare:**

1. **`openstack_compute_instance_v2.api_proxy`** — VM con Nginx
   - Subnet pubblica, security group `proxy_sg`
   - `user_data` che:
     - Installa Nginx
     - Configura proxy pass verso il backend (LB VIP o direttamente le istanze)
     - Configura CORS headers (replica `cors_configuration` del gateway)
     - I percorsi pubblici (`/api/search`, `OPTIONS`) non richiedono auth
     - I percorsi protetti (`ANY /{proxy+}`) richiedono validazione (nota sotto)

2. **`openstack_networking_floatingip_v2.proxy_fip`** — floating IP per il proxy

3. **`openstack_dns_recordset_v2.api_record`** — record DNS `api.myapp.local.` che
   punta al proxy

**Funzionalità del gateway AWS replicate:**

| Funzionalità AWS                  | Implementazione Nginx                        |
|-----------------------------------|----------------------------------------------|
| `cors_configuration`              | `add_header` CORS in ogni location block     |
| `HTTP_PROXY` integration          | `proxy_pass` al backend                      |
| `overwrite:path`                  | `proxy_pass http://backend$request_uri`      |
| `OPTIONS /{proxy+}` senza auth   | `location` separata con `return 204`         |
| `GET /api/search` senza auth     | `location /api/search` senza auth check      |
| `ANY /{proxy+}` con JWT auth     | Header forwarding (senza validazione JWT)    |
| Header injection (`x-user-*`)    | `proxy_set_header` con valori dall'header    |

**Limitazione importante:** Nginx base non valida JWT nativamente. Opzioni:
- Usare `ngx_http_auth_request_module` con un endpoint di validazione
- Usare OpenResty (Nginx + Lua) con una libreria JWT
- Delegare la validazione al backend (approccio più semplice)

Per il contesto DevStack/dev, il proxy si limiterà a:
- Instradare le richieste al backend
- Iniettare gli header CORS
- Inoltrare gli header Authorization al backend per la validazione

**Outputs:** `api_proxy_endpoint`, `api_proxy_floating_ip`

---

### Step 9: `main.tf` (Dotenv) — Finalizzazione

Aggiornare il `local_file.dotenv` per generare `/config/openstack.env`:

```
# Generato automaticamente da Terraform su DevStack

# --- CONFIGURAZIONE FRONTEND ---
PUBLIC_AUTH_URL=<keystone_auth_url>
PUBLIC_PROJECT_ID=<app_project_id>
PUBLIC_REGION=RegionOne
PUBLIC_SWIFT_ENDPOINT=http://192.168.1.13:8080

# --- API PROXY (sostituisce API Gateway) ---
PUBLIC_API_ENDPOINT=http://<proxy_floating_ip>

# --- CONFIGURAZIONE BACKEND ---
OS_AUTH_URL=<keystone_auth_url>
OS_REGION=RegionOne
OS_PROJECT_ID=<app_project_id>
OS_APP_CREDENTIAL_ID=<backend_app_cred_id>
OS_APP_CREDENTIAL_SECRET=<backend_app_cred_secret>

# --- LOAD BALANCER ---
LB_VIP_ADDRESS=<lb_floating_ip>

# --- STORAGE ---
SWIFT_FRONTEND_CONTAINER=my-app-frontend-container
SWIFT_FRONTEND_URL=http://192.168.1.13:8080/v1/AUTH_<project>/my-app-frontend-container/
SWIFT_MEDIA_CONTAINER=my-app-media-assets
SWIFT_MEDIA_URL=http://192.168.1.13:8080/v1/AUTH_<project>/my-app-media-assets

# --- DATABASE ---
DB_HOST=<trove_instance_ip>
DB_PORT=5432
DB_USER=dbadmin
DB_PASS=<db_password>
DB_NAME=myappdb

# --- DNS ---
DNS_ZONE=myapp.local
```

---

## Ordine di Implementazione

| #  | File            | Motivo dell'ordine                                    |
|----|-----------------|-------------------------------------------------------|
| 1  | `variables.tf`  | Fondazione — tutte le altre risorse ne dipendono      |
| 2  | `main.tf`       | Provider (senza dotenv, che viene aggiunto alla fine) |
| 3  | `network.tf`    | Rete — prerequisito per tutte le risorse              |
| 4  | `security.tf`   | Security groups — necessari per compute, DB, proxy    |
| 5  | `storage.tf`    | Swift containers + Trove DB + seed dati               |
| 6  | `compute.tf`    | LB + ASG (Heat) + debug instance                     |
| 7  | `identity.tf`   | Keystone: ruoli, utenti, credenziali                  |
| 8  | `gateway.tf`    | Nginx reverse proxy (dipende da LB VIP)              |
| 9  | `main.tf`       | Aggiunta del dotenv con tutti gli output              |

---

## File Ausiliari

| File                    | Descrizione                                          |
|-------------------------|------------------------------------------------------|
| `templates/asg.yaml`    | Template Heat (HOT) per ASG + scaling policy + alarm |

Questo file contiene il template YAML che Heat usa per orchestrare l'auto-scaling
group. Viene referenziato da `compute.tf` tramite `templatefile()`.

---

## Riepilogo Gap Residui

Anche con tutti i componenti disponibili, restano differenze architetturali
irriducibili tra AWS e OpenStack:

| Funzionalità              | Stato         | Nota                                        |
|---------------------------|---------------|---------------------------------------------|
| Cognito User Pool         | Parziale      | Keystone non è un IdP consumer-facing       |
| Cognito Hosted UI         | Non replicato | Necessita Keycloak o simile                 |
| JWT auth nel Gateway      | Parziale      | Nginx non valida JWT nativamente            |
| CDN (CloudFront)          | Non replicato | Swift staticweb serve direttamente          |
| S3 Website custom domain  | Non replicato | URL Swift con path `AUTH_project/container`  |
| API Gateway managed       | Workaround    | Nginx su VM (non gestito, non serverless)   |
| Octavia L7 (HTTP routing) | Non disponibile| OVN provider = solo L4 (TCP)               |
| Trove performance         | Variabile     | Lento in nested virtualization              |
