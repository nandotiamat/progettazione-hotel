# Piano di Migrazione: AWS (LocalStack) -> OpenStack (DevStack)

## Panoramica

Tradurre l'infrastruttura Terraform attualmente destinata ad AWS/LocalStack in una
configurazione equivalente per OpenStack/DevStack, mantenendo la struttura a 3 livelli
(frontend, backend, database) con un bastion host per l'accesso SSH.

---

## Vincoli dell'Ambiente Target

| Aspetto | Dettaglio |
|---|---|
| Host | Windows |
| Guest VM | Linux, 75GB disco, 6 vCPU, 32GB RAM |
| OpenStack | DevStack `stable/2025.1` |
| Servizi attivi | Nova, Neutron (OVN), Octavia (OVN provider), Swift, Keystone, Glance, Horizon |
| Servizi **non** attivi | Octavia Amphora (disabilitato), Heat, Barbican, Designate, Cinder (default DevStack) |
| Autenticazione | `clouds.yaml` |

---

## Mappatura AWS -> OpenStack

| AWS Resource | OpenStack Equivalent | Note |
|---|---|---|
| VPC + Subnets | `openstack_networking_network_v2` + `openstack_networking_subnet_v2` | Singola rete privata `10.0.1.0/24` |
| Internet Gateway + Route Table | `openstack_networking_router_v2` + `openstack_networking_router_interface_v2` | Router collegato alla rete esterna |
| ALB (Application Load Balancer) | `openstack_lb_loadbalancer_v2` (Octavia, provider OVN) | Layer 4 TCP, non Layer 7 |
| ASG + Launch Template | Istanze Nova individuali | OpenStack non ha ASG nativo; useremo istanze statiche |
| EC2 Instances | `openstack_compute_instance_v2` | Con cloud-init e keypair |
| Security Groups | `openstack_networking_secgroup_v2` + `openstack_networking_secgroup_rule_v2` | Regole equivalenti |
| S3 Bucket | `openstack_objectstorage_container_v1` (Swift) | Solo per media assets |
| S3 Object | `openstack_objectstorage_object_v1` (Swift) | Seed delle immagini |
| RDS PostgreSQL | Istanza Nova con cloud-init PostgreSQL | DevStack non ha Trove; il DB gira su una VM |
| IAM Roles/Policies | `openstack_identity_role_v3` + `openstack_identity_user_v3` + ACL Swift | Ruoli Keystone + ACL sul container |
| Cognito | **Eliminato** | Nessun equivalente diretto in DevStack |
| API Gateway | **Eliminato** | Nessun equivalente diretto in DevStack |
| CloudFront | **Eliminato** | Nessun equivalente diretto in DevStack |
| Route53 | **Eliminato** | Designate non abilitato in DevStack |
| AMI | `openstack_images_image_v2` (Glance) | Ubuntu Jammy cloud image |
| Key Pair | `openstack_compute_keypair_v2` | Chiave SSH generata da Terraform |

---

## Risorse da NON Migrare

I seguenti servizi AWS non hanno equivalenti nel DevStack target e verranno omessi:

1. **Cognito** (identity.tf) -- nessun IdP in DevStack
2. **API Gateway** (gateway.tf) -- nessun API gateway in DevStack
3. **CloudFront** (frontend_distribution.tf) -- nessun CDN in DevStack
4. **Route53** (parte di network.tf) -- Designate non abilitato
5. **CloudWatch Alarms** (parte di compute.tf) -- nessun equivalente
6. **Auto Scaling Group** (parte di compute.tf) -- nessun equivalente nativo

---

## File da Creare/Modificare

Mantenendo la convenzione di organizzazione per dominio del progetto originale:

| File | Contenuto |
|---|---|
| `main.tf` | Blocco `terraform`, provider `openstack`, generazione file `.env` |
| `variables.tf` | Tutte le variabili di input centralizzate |
| `network.tf` | Rete privata, subnet, router, floating IPs |
| `security.tf` | Security groups: Bastion, Frontend, Backend, Database |
| `compute.tf` | Flavor, immagine Glance, keypair, 5 istanze Nova |
| `storage.tf` | Container Swift, upload seed media, ruoli/utenti Keystone |
| `cloud-init/frontend-init-node.yaml` | Template cloud-init per nodi frontend |
| `cloud-init/backend-init-node.yaml` | Template cloud-init per nodo backend |
| `cloud-init/cloud-init-db.yaml` | Template cloud-init per nodo database |

File da **rimuovere** (non applicabili a OpenStack):

| File | Motivo |
|---|---|
| `iam.tf` | Sostituito da ruoli Keystone in `storage.tf` |
| `identity.tf` | Cognito non ha equivalente |
| `gateway.tf` | API Gateway non ha equivalente |
| `frontend_distribution.tf` | CloudFront non ha equivalente |

---

## Piano di Implementazione Step-by-Step

### Step 0: Pulizia e Setup

- Rimuovere tutti i file `.tf` esistenti (sono specifici AWS)
- Creare la directory `cloud-init/` per i file di configurazione
- Copiare i file seed_media dal percorso corrente (se presenti)

### Step 1: `main.tf` -- Provider e Configurazione Base

- Blocco `terraform` con `required_providers` per `openstack` (ultima versione)
- Provider `openstack` con autenticazione via `clouds.yaml` (nessuna credenziale hardcoded)
- Risorsa `local_file` per generare un `.env` con gli output dell'infrastruttura

### Step 2: `variables.tf` -- Variabili

Variabili da definire:
- `external_network_name` (default: `"public"`) -- rete esterna DevStack
- `dns_nameservers` (default: `["8.8.8.8"]`)
- `db_password` (default: `"test"`) -- password PostgreSQL
- `db_user` (default: `"dbadmin"`)
- `db_name` (default: `"myappdb"`)
- `image_url` (default: URL cloud image Ubuntu Jammy)
- `keypair_private_key_path` (default: `"~/.ssh/hotel-key.pem"`)

### Step 3: `network.tf` -- Rete e Router

Risorse:
- `openstack_networking_network_v2.hotel_net` -- rete privata `hotel-private-net`
- `openstack_networking_subnet_v2.hotel_subnet` -- subnet `10.0.1.0/24`, DHCP abilitato, DNS nameservers
- `data.openstack_networking_network_v2.external` -- riferimento alla rete esterna
- `openstack_networking_router_v2.hotel_router` -- router con gateway esterno
- `openstack_networking_router_interface_v2.router_iface` -- interfaccia router-subnet
- `openstack_networking_floatingip_v2.bastion_fip` -- floating IP per bastion
- `openstack_networking_floatingip_v2.lb_fip` -- floating IP per load balancer
- `openstack_compute_floatingip_associate_v2.bastion_fip_assoc` -- associazione FIP al bastion

Output: `network_id`, `subnet_id`, `router_id`, `bastion_floating_ip`, `lb_floating_ip`

### Step 4: `security.tf` -- Security Groups

4 security groups con regole di segmentazione rigorosa:

1. **`bastion_sg`** -- Bastion Security Group
   - Ingress: TCP/22 da `0.0.0.0/0`
   - Egress: tutto

2. **`frontend_sg`** -- Frontend Security Group
   - Ingress: TCP/80 da `0.0.0.0/0` (traffico HTTP dal LB)
   - Ingress: TCP/22 da `bastion_sg` (accesso SSH via bastion)
   - Egress: tutto

3. **`backend_sg`** -- Backend Security Group
   - Ingress: TCP/80 da `frontend_sg` (API REST)
   - Ingress: TCP/22 da `frontend_sg` (accesso SSH via frontend)
   - Egress: tutto

4. **`database_sg`** -- Database Security Group
   - Ingress: TCP/5432 da `backend_sg` (PostgreSQL)
   - Egress: tutto

Output: gli ID dei 4 security groups

### Step 5: `compute.tf` -- Flavor, Immagine, Keypair e Istanze

Risorse:

- **Glance Image**: `openstack_images_image_v2.ubuntu_jammy`
  - `image_source_url` per scaricare `jammy-server-cloudimg-amd64.img`
  - `container_format = "bare"`, `disk_format = "qcow2"`

- **Flavor**: `openstack_compute_flavor_v2.hotel_flavor`
  - 1 vCPU, 2048 MB RAM, 10 GB disco

- **Keypair**: `tls_private_key` + `openstack_compute_keypair_v2.hotel_keypair`
  - Generazione chiave RSA tramite provider `tls`
  - Salvataggio chiave privata in `~/.ssh/hotel-key.pem` via `local_file`

- **Istanze** (5 totali):
  1. `openstack_compute_instance_v2.frontend[0]` -- Frontend 1
  2. `openstack_compute_instance_v2.frontend[1]` -- Frontend 2
  3. `openstack_compute_instance_v2.backend` -- Backend
  4. `openstack_compute_instance_v2.database` -- Database
  5. `openstack_compute_instance_v2.bastion` -- Bastion (immagine cirros)
  - Tutte nella rete `hotel-private-net`, con i rispettivi security groups
  - Cloud-init via `user_data` per le istanze Ubuntu

Output: IP delle istanze, ID del keypair

### Step 6: Cloud-Init Files

3 file di configurazione cloud-init:

1. **`cloud-init/frontend-init-node.yaml`**
   - Installa `nginx` (o usa python http.server)
   - Configura una pagina HTML statica: `Frontend node {i}`
   - Avvia il servizio HTTP sulla porta 80
   - Sarà templatizzato con `templatefile()` per iniettare l'indice del nodo

2. **`cloud-init/backend-init-node.yaml`**
   - Installa `python3`, `pip`, `fastapi`, `uvicorn`
   - Crea un semplice server FastAPI
   - Avvia uvicorn sulla porta 80

3. **`cloud-init/cloud-init-db.yaml`**
   - Installa `postgresql`
   - Configura `pg_hba.conf` per accettare connessioni dalla subnet
   - Configura `postgresql.conf` per ascoltare su tutte le interfacce
   - Crea utente e database
   - Esegue lo schema SQL per il seeding

### Step 7: `storage.tf` -- Swift, Keystone e Seeding

Risorse:

- **Swift Container**: `openstack_objectstorage_container_v1.hotel_assets`
  - Nome: `hotel-assets`

- **Keystone Roles**:
  - `openstack_identity_role_v3.media_reader`
  - `openstack_identity_role_v3.media_uploader`

- **Keystone Users**:
  - `openstack_identity_user_v3.app_frontend_reader`
  - `openstack_identity_user_v3.app_frontend_uploader`

- **Role Assignments**: Binding dei ruoli agli utenti sul progetto

- **Container ACLs**: Read/Write ACL sul container Swift usando i ruoli creati

- **Seed Media**: `openstack_objectstorage_object_v1.media_seed`
  - Upload delle 17 immagini via `for_each` (stessa logica dell'AWS originale)

- **Secrets/`.env`**: Generazione file `.env` con credenziali e endpoint (tramite `local_file` in `main.tf`)
  - Le password degli utenti Keystone saranno generate con `random_password`
  - Nessun segreto hardcoded negli output

Output: nome container Swift, endpoint

### Step 8: Load Balancer (in `network.tf` o file dedicato)

Risorse da aggiungere a `network.tf`:

- `openstack_lb_loadbalancer_v2.hotel_lb` -- LB Octavia con `loadbalancer_provider = "ovn"`, sulla subnet privata
- `openstack_lb_listener_v2.http_listener` -- Listener TCP porta 80
- `openstack_lb_pool_v2.frontend_pool` -- Pool con algoritmo `SOURCE_IP_PORT`
- `openstack_lb_member_v2.frontend_member[0]` -- Membro pool (frontend 1, porta 80)
- `openstack_lb_member_v2.frontend_member[1]` -- Membro pool (frontend 2, porta 80)
- `openstack_lb_monitor_v2.tcp_monitor` -- Health monitor TCP (delay 5s, timeout 3s, max_retries 3)
- Associazione floating IP al VIP del LB

---

## Ordine delle Dipendenze

```
Step 1 (main.tf)
  |
Step 2 (variables.tf)
  |
Step 3 (network.tf) -- rete, subnet, router
  |
Step 4 (security.tf) -- SGs (dipendono dalla rete)
  |
Step 5 (compute.tf) -- immagine, flavor, keypair, istanze
  |          |                    (dipendono da rete + SGs)
  |          |
Step 6 (cloud-init/) -- file cloud-init referenziati da compute
  |
Step 7 (storage.tf) -- Swift, Keystone users/roles, seed
  |
Step 8 (LB in network.tf) -- Load Balancer (dipende da subnet + istanze frontend)
  |
Final: `.env` generation in main.tf (dipende da tutti gli output)
```

---

## Rischi e Considerazioni

1. **Octavia OVN Provider**: Con `OCTAVIA_USE_AMPHORA_PROVIDER=False`, il LB usa il provider OVN nativo. Il metodo `SOURCE_IP_PORT` potrebbe non essere supportato dal provider OVN -- verificare e usare `SOURCE_IP` come fallback.

2. **Floating IP sul VIP**: L'associazione di una floating IP al VIP del Load Balancer OVN richiede `openstack_networking_floatingip_associate_v2` con il `port_id` del VIP -- attenzione alla sequenza di dipendenze.

3. **Cloud Image Download**: Il download dell'immagine Ubuntu Jammy (~700MB) via `image_source_url` potrebbe richiedere tempo e la VM DevStack deve avere accesso a internet.

4. **Risorse limitate**: Con 6 vCPU e 32GB RAM totali per DevStack, 5 VM con il flavor `hotel_flavor` (1 vCPU, 2GB RAM ciascuna) consumano 5 vCPU e 10GB RAM -- verificare che rimanga sufficiente per i servizi OpenStack.

5. **Cloud-init su cirros**: Il bastion usa l'immagine `cirros` che ha supporto cloud-init molto limitato. Non verrà configurato con cloud-init personalizzato.

6. **Seeding del DB**: A differenza dell'originale che usa `psql` via `local-exec`, qui il seeding avverrà via cloud-init embedded nel file YAML del nodo database, poiche la VM non sara raggiungibile direttamente dalla macchina che esegue Terraform.

7. **Nessun segreto negli output**: Le password saranno generate con `random_password` e scritte solo nel file `.env` locale, mai esposte come output Terraform.
