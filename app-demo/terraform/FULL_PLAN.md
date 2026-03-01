# FULL_PLAN.md — Piano Completo di Implementazione OpenStack (DevStack)

## Obiettivo

Scrivere da zero una configurazione Terraform per OpenStack/DevStack che riproduca
l'architettura a 3 livelli dell'applicazione hotel originariamente costruita su AWS/LocalStack.
Il nodo DevStack e' gia' operativo con tutti i componenti necessari installati.

---

## Servizi DevStack Disponibili

| Servizio | Componente | Uso nel progetto |
|---|---|---|
| **Keystone** | Identity v3 | Utenti, ruoli, progetti, autenticazione `clouds.yaml` |
| **Nova** | Compute | 5 istanze VM (2 frontend, 1 backend, 1 database, 1 bastion) |
| **Glance** | Image | Upload immagine Ubuntu Jammy cloud-img |
| **Neutron + OVN** | Networking | Rete privata, subnet, router, security groups, floating IPs |
| **Octavia (OVN)** | Load Balancing | LB Layer 4 TCP con provider OVN |
| **Swift** | Object Storage | Container per media assets + seed immagini |
| **Horizon** | Dashboard | Non usato da Terraform (accesso UI opzionale) |

---

## Provider Terraform Richiesti

| Provider | Source | Uso |
|---|---|---|
| `openstack` | `terraform-provider-openstack/openstack` | Tutte le risorse OpenStack |
| `tls` | `hashicorp/tls` | Generazione chiave SSH RSA |
| `local` | `hashicorp/local` | Scrittura file `.env` e chiave privata SSH |
| `random` | `hashicorp/random` | Generazione password utenti Keystone |

---

## Struttura File Target

```
terraform/
  main.tf                              # terraform block, provider, .env generation
  variables.tf                         # tutte le variabili centralizzate
  network.tf                           # rete, subnet, router, floating IPs
  security.tf                          # 4 security groups + regole
  compute.tf                           # glance image, flavor, keypair, 5 istanze
  loadbalancer.tf                      # Octavia LB, listener, pool, members, monitor
  storage.tf                           # Swift container, seed media, Keystone users/roles
  cloud-init/
    frontend-init-node.yaml            # template cloud-init frontend (templatizzato)
    backend-init-node.yaml             # cloud-init backend (FastAPI)
    cloud-init-db.yaml                 # cloud-init database (PostgreSQL)
  seed_media/                          # 17 immagini PNG gia' presenti (via symlink o copia)
```

File AWS da rimuovere: `iam.tf`, `identity.tf`, `gateway.tf`, `frontend_distribution.tf`.
File AWS da sovrascrivere completamente: `main.tf`, `variables.tf`, `network.tf`,
`security.tf`, `compute.tf`, `storage.tf`.

---

## Piano di Implementazione Dettagliato

### Step 1: Pulizia e Scaffolding

**Azioni:**
- Rimuovere tutti i file `.tf` esistenti (specifici AWS/LocalStack)
- Creare la directory `cloud-init/`
- Creare un symlink o copiare `seed_media/` da `../terraform_content/seed_media/`
  nella directory terraform (i file devono essere raggiungibili via `${path.module}/seed_media/`)

**File coinvolti:** nessun file `.tf` creato in questo step.

---

### Step 2: `variables.tf` — Variabili Centralizzate

Tutte le variabili di input, ognuna con `description`, `type` e `default`.

| Variabile | Tipo | Default | Descrizione |
|---|---|---|---|
| `external_network_name` | `string` | `"public"` | Nome della rete esterna DevStack |
| `dns_nameservers` | `list(string)` | `["8.8.8.8"]` | DNS per la subnet privata |
| `private_network_cidr` | `string` | `"10.0.1.0/24"` | CIDR della subnet privata |
| `db_user` | `string` | `"dbadmin"` | Username PostgreSQL |
| `db_name` | `string` | `"myappdb"` | Nome database PostgreSQL |
| `db_password` | `string` | `"test"` | Password PostgreSQL (solo per dev locale) |
| `image_url` | `string` | `"https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"` | URL immagine Ubuntu Jammy |
| `keypair_private_key_path` | `string` | `"~/.ssh/hotel-key.pem"` | Percorso salvataggio chiave privata SSH |
| `swift_container_name` | `string` | `"hotel-assets"` | Nome container Swift |
| `env_file_path` | `string` | `"./openstack.env"` | Percorso file `.env` generato |

---

### Step 3: `main.tf` — Provider e Configurazione Base

**Contenuto:**

1. **Blocco `terraform`**: `required_providers` per `openstack`, `tls`, `local`, `random`.
   Versioni: ultima disponibile per tutti.

2. **Provider `openstack`**: Nessuna credenziale hardcoded. Autenticazione delegata
   interamente a `clouds.yaml` (il provider OpenStack lo legge automaticamente).
   Eventuale variabile `cloud` per selezionare il cloud name dal file `clouds.yaml`.

3. **Risorsa `local_file.dotenv`**: Generazione `.env` con tutti gli output
   dell'infrastruttura. Contenuto (segreti inclusi solo qui, mai negli output TF):

   ```
   # Generato automaticamente da Terraform

   # --- NETWORK ---
   BASTION_FLOATING_IP=<bastion FIP>
   LB_FLOATING_IP=<LB FIP>

   # --- COMPUTE ---
   FRONTEND_1_IP=<IP privato frontend 1>
   FRONTEND_2_IP=<IP privato frontend 2>
   BACKEND_IP=<IP privato backend>
   DATABASE_IP=<IP privato database>
   BASTION_IP=<IP privato bastion>

   # --- DATABASE ---
   DB_HOST=<IP privato database>
   DB_PORT=5432
   DB_USER=<var.db_user>
   DB_PASS=<var.db_password>
   DB_NAME=<var.db_name>

   # --- SWIFT ---
   SWIFT_CONTAINER=<nome container>
   SWIFT_READER_USER=app_frontend_reader
   SWIFT_READER_PASS=<password generata>
   SWIFT_UPLOADER_USER=app_frontend_uploader
   SWIFT_UPLOADER_PASS=<password generata>

   # --- SSH ---
   SSH_KEY_PATH=<percorso chiave privata>
   ```

**Output co-locati:** Nessuno in `main.tf` (gli output stanno nei file di dominio).

---

### Step 4: `network.tf` — Rete, Subnet, Router, Floating IPs

**Risorse:**

| Risorsa | Tipo | Identificatore TF | Nome OpenStack | Dettagli |
|---|---|---|---|---|
| Data source rete esterna | `data.openstack_networking_network_v2` | `external` | — | Lookup per `var.external_network_name` |
| Rete privata | `openstack_networking_network_v2` | `hotel_net` | `hotel-private-net` | `admin_state_up = true` |
| Subnet | `openstack_networking_subnet_v2` | `hotel_subnet` | `hotel-private-subnet` | CIDR `10.0.1.0/24`, DHCP abilitato, `dns_nameservers` da variabile |
| Router | `openstack_networking_router_v2` | `hotel_router` | `hotel-router` | `external_network_id` dalla data source |
| Interfaccia router | `openstack_networking_router_interface_v2` | `router_iface` | — | Collega router alla subnet privata |
| Floating IP bastion | `openstack_networking_floatingip_v2` | `bastion_fip` | — | Dalla rete esterna |
| Floating IP LB | `openstack_networking_floatingip_v2` | `lb_fip` | — | Dalla rete esterna |

**Associazioni floating IP:**
- Bastion FIP: associata in `compute.tf` con `openstack_compute_floatingip_associate_v2`
- LB FIP: associata in `loadbalancer.tf` con `openstack_networking_floatingip_associate_v2`
  al `vip_port_id` del load balancer

**Output (in fondo al file, dopo `# --- OUTPUTS ---`):**
- `network_id` — ID della rete privata
- `subnet_id` — ID della subnet
- `router_id` — ID del router
- `bastion_floating_ip` — Indirizzo floating IP del bastion
- `lb_floating_ip` — Indirizzo floating IP del load balancer

---

### Step 5: `security.tf` — Security Groups e Regole

4 security groups con segmentazione rigorosa. Ogni SG ha una regola di egress
implicita (OpenStack permette tutto l'egress di default) ma aggiungeremo regole
di egress esplicite per chiarezza.

**1. Bastion SG** (`bastion_sg` / `"bastion-security-group"`)

| Direzione | Protocollo | Porta | Sorgente | Scopo |
|---|---|---|---|---|
| Ingress | TCP | 22 | `0.0.0.0/0` | SSH da ovunque |
| Egress | * | * | `0.0.0.0/0` | Tutto il traffico in uscita |

**2. Frontend SG** (`frontend_sg` / `"frontend-security-group"`)

| Direzione | Protocollo | Porta | Sorgente | Scopo |
|---|---|---|---|---|
| Ingress | TCP | 80 | `0.0.0.0/0` | HTTP (dal Load Balancer o diretto) |
| Ingress | TCP | 22 | `bastion_sg` | SSH dal bastion |
| Egress | * | * | `0.0.0.0/0` | Tutto il traffico in uscita (pacchetti, aggiornamenti) |

**3. Backend SG** (`backend_sg` / `"backend-security-group"`)

| Direzione | Protocollo | Porta | Sorgente | Scopo |
|---|---|---|---|---|
| Ingress | TCP | 80 | `frontend_sg` | API REST dai frontend |
| Ingress | TCP | 22 | `frontend_sg` | SSH dal frontend (hop via bastion) |
| Egress | * | * | `0.0.0.0/0` | Tutto il traffico in uscita |

**4. Database SG** (`database_sg` / `"database-security-group"`)

| Direzione | Protocollo | Porta | Sorgente | Scopo |
|---|---|---|---|---|
| Ingress | TCP | 5432 | `backend_sg` | PostgreSQL dal backend |
| Egress | * | * | `0.0.0.0/0` | Tutto il traffico in uscita |

**Implementazione regole:** Ogni regola e' una risorsa separata
`openstack_networking_secgroup_rule_v2`. Le regole che referenziano un altro SG
usano `remote_group_id`; quelle aperte usano `remote_ip_prefix = "0.0.0.0/0"`.

**Output (dopo `# --- OUTPUTS ---`):**
- `bastion_sg_id`
- `frontend_sg_id`
- `backend_sg_id`
- `database_sg_id`

---

### Step 6: `compute.tf` — Immagine Glance, Flavor, Keypair e Istanze

**6a. Immagine Glance**

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Ubuntu Jammy | `openstack_images_image_v2` | `ubuntu_jammy` | `name = "ubuntu-jammy-cloudimg"`, `image_source_url = var.image_url`, `container_format = "bare"`, `disk_format = "qcow2"`, `visibility = "public"` |
| Cirros | `data.openstack_images_image_v2` | `cirros` | Data source per l'immagine cirros gia' presente in DevStack (filtro per nome `"cirros-*"`) |

**6b. Flavor**

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Hotel flavor | `openstack_compute_flavor_v2` | `hotel_flavor` | `name = "hotel_flavor"`, 1 vCPU, 2048 MB RAM, 10 GB disco |

**6c. Keypair SSH**

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Chiave TLS | `tls_private_key` | `hotel_ssh_key` | Algoritmo RSA, 4096 bit |
| Keypair OpenStack | `openstack_compute_keypair_v2` | `hotel_keypair` | `name = "hotel-keypair"`, public_key dalla risorsa TLS |
| File chiave privata | `local_sensitive_file` | `private_key_pem` | Salva in `var.keypair_private_key_path`, permessi `0600` |

**6d. Istanze Nova (5 totali)**

Tutte le istanze condividono: `flavor_id`, `key_pair`, rete `hotel-private-net`.

| # | Identificatore TF | Nome OpenStack | Immagine | SG | Cloud-init | Note |
|---|---|---|---|---|---|---|
| 1-2 | `openstack_compute_instance_v2.frontend` | `hotel-frontend-{i+1}` | `ubuntu_jammy` | `frontend_sg` | `frontend-init-node.yaml` (templatizzato con indice) | `count = 2` |
| 3 | `openstack_compute_instance_v2.backend` | `hotel-backend` | `ubuntu_jammy` | `backend_sg` | `backend-init-node.yaml` | Singola istanza |
| 4 | `openstack_compute_instance_v2.database` | `hotel-database` | `ubuntu_jammy` | `database_sg` | `cloud-init-db.yaml` (templatizzato con credenziali DB) | Singola istanza |
| 5 | `openstack_compute_instance_v2.bastion` | `hotel-bastion` | `cirros` (data source) | `bastion_sg` | Nessuno (cirros ha supporto cloud-init limitato) | Singola istanza |

**Associazione Floating IP Bastion:**
- `openstack_compute_floatingip_associate_v2.bastion_fip_assoc` — associa il FIP
  allocato in `network.tf` all'istanza bastion

**Blocco `network` nelle istanze:**
```hcl
network {
  uuid = openstack_networking_network_v2.hotel_net.id
}
```

**Cloud-init:** Le istanze Ubuntu usano `user_data` con il contenuto dei file
cloud-init, processati con `templatefile()` dove serve (frontend per l'indice,
database per le credenziali).

**Output (dopo `# --- OUTPUTS ---`):**
- `frontend_ips` — Lista degli IP privati dei frontend
- `backend_ip` — IP privato del backend
- `database_ip` — IP privato del database
- `bastion_ip` — IP privato del bastion
- `bastion_floating_ip_address` — Floating IP del bastion (duplicato intenzionale per comodita')

---

### Step 7: Cloud-Init Files

I file cloud-init seguono il formato `cloud-config` standard. Le istanze Ubuntu
Jammy li eseguono automaticamente al primo boot.

**7a. `cloud-init/frontend-init-node.yaml`**

Questo file sara' un template Terraform (`templatefile()`) che riceve la variabile
`node_index`.

```yaml
#cloud-config
package_update: true
packages:
  - nginx

write_files:
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html><body><h1>Frontend node ${node_index}</h1></body></html>

runcmd:
  - systemctl enable nginx
  - systemctl start nginx
```

**7b. `cloud-init/backend-init-node.yaml`**

```yaml
#cloud-config
package_update: true
packages:
  - python3
  - python3-pip
  - python3-venv

write_files:
  - path: /opt/api/main.py
    content: |
      from fastapi import FastAPI
      app = FastAPI()

      @app.get("/")
      def root():
          return {"status": "ok", "service": "hotel-backend"}

      @app.get("/health")
      def health():
          return {"status": "healthy"}

runcmd:
  - python3 -m venv /opt/api/venv
  - /opt/api/venv/bin/pip install fastapi uvicorn
  - cd /opt/api && /opt/api/venv/bin/uvicorn main:app --host 0.0.0.0 --port 80 &
```

**7c. `cloud-init/cloud-init-db.yaml`**

Template Terraform con variabili: `db_user`, `db_password`, `db_name`, `subnet_cidr`.

```yaml
#cloud-config
package_update: true
packages:
  - postgresql
  - postgresql-contrib

runcmd:
  # Configura PostgreSQL per accettare connessioni remote
  - |
    sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_password}';"
    sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};"
  # Configura ascolto su tutte le interfacce
  - sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
  # Configura pg_hba.conf per la subnet
  - echo "host all all ${subnet_cidr} md5" >> /etc/postgresql/*/main/pg_hba.conf
  - systemctl restart postgresql
```

---

### Step 8: `loadbalancer.tf` — Octavia Load Balancer (OVN Provider)

File dedicato per il load balancer (separato da `network.tf` per chiarezza, dato
il numero di risorse coinvolte).

**Risorse:**

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Load Balancer | `openstack_lb_loadbalancer_v2` | `hotel_lb` | `name = "hotel-lb"`, `loadbalancer_provider = "ovn"`, `vip_subnet_id` = subnet privata |
| Listener | `openstack_lb_listener_v2` | `http_listener` | `name = "hotel-http-listener"`, `protocol = "TCP"`, `protocol_port = 80` |
| Pool | `openstack_lb_pool_v2` | `frontend_pool` | `name = "hotel-frontend-pool"`, `protocol = "TCP"`, `lb_method = "SOURCE_IP_PORT"`, collegato al listener |
| Membro 1 | `openstack_lb_member_v2` | `frontend_member[0]` | IP del frontend 1, `protocol_port = 80`, `subnet_id` |
| Membro 2 | `openstack_lb_member_v2` | `frontend_member[1]` | IP del frontend 2, `protocol_port = 80`, `subnet_id` |
| Health Monitor | `openstack_lb_monitor_v2` | `tcp_monitor` | `type = "TCP"`, `delay = 5`, `timeout = 3`, `max_retries = 3` |
| Floating IP assoc. | `openstack_networking_floatingip_associate_v2` | `lb_fip_assoc` | Associa `lb_fip.address` al `vip_port_id` del LB |

**Nota OVN:** Con il provider OVN, tutto e' Layer 4. Il protocollo deve essere `TCP`
(non `HTTP`). L'algoritmo `SOURCE_IP_PORT` e' supportato dal provider OVN di Octavia.

**Output (dopo `# --- OUTPUTS ---`):**
- `lb_vip_address` — Indirizzo VIP privato del load balancer
- `lb_floating_ip_address` — Floating IP pubblica del load balancer

---

### Step 9: `storage.tf` — Swift, Keystone Identity, Seeding

**9a. Password Generate**

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Password reader | `random_password` | `reader_password` | `length = 24`, `special = false` |
| Password uploader | `random_password` | `uploader_password` | `length = 24`, `special = false` |

**9b. Keystone — Progetto, Ruoli e Utenti**

Per l'accesso granulare a Swift servono: un progetto dedicato (o il progetto corrente),
ruoli custom e utenti con quei ruoli assegnati.

| Risorsa | Tipo | Identificatore TF | Nome Keystone | Dettagli |
|---|---|---|---|---|
| Data source progetto | `data.openstack_identity_project_v3` | `current` | — | Recupera il progetto corrente (dal `clouds.yaml`) |
| Ruolo reader | `openstack_identity_role_v3` | `media_reader` | `media_reader` | Ruolo custom per lettura media |
| Ruolo uploader | `openstack_identity_role_v3` | `media_uploader` | `media_uploader` | Ruolo custom per upload media |
| Utente reader | `openstack_identity_user_v3` | `app_frontend_reader` | `app_frontend_reader` | Password da `random_password`, progetto di default |
| Utente uploader | `openstack_identity_user_v3` | `app_frontend_uploader` | `app_frontend_uploader` | Password da `random_password`, progetto di default |
| Assegnazione ruolo reader | `openstack_identity_role_assignment_v3` | `reader_assignment` | — | Binding `media_reader` -> `app_frontend_reader` sul progetto |
| Assegnazione ruolo uploader | `openstack_identity_role_assignment_v3` | `uploader_assignment` | — | Binding `media_uploader` -> `app_frontend_uploader` sul progetto |

**9c. Swift Container e ACLs**

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Container | `openstack_objectstorage_container_v1` | `hotel_assets` | `name = "hotel-assets"`, con metadata per read/write ACL |

Le ACL Swift usano il formato `project:user`:
- `container_read` = formato ACL che consente lettura a `app_frontend_reader`
- `container_write` = formato ACL che consente scrittura a `app_frontend_uploader`

**9d. Seed Media — Upload immagini**

Stessa logica dell'AWS originale: un blocco `locals` con la mappa dei 17 file,
e un `for_each` per caricarli.

| Risorsa | Tipo | Identificatore TF | Dettagli |
|---|---|---|---|
| Locals | `locals.media_files` | — | Mappa di 17 entry: chiave oggetto Swift -> percorso file locale |
| Oggetti Swift | `openstack_objectstorage_object_v1` | `media_seed` | `for_each = local.media_files`, `content_type` dinamico per estensione |

**Output (dopo `# --- OUTPUTS ---`):**
- `swift_container_name` — Nome del container Swift
- `keystone_reader_user` — Nome utente reader (non sensibile)
- `keystone_uploader_user` — Nome utente uploader (non sensibile)

**Nota:** Le password degli utenti Keystone NON sono esposte come output.
Sono scritte solo nel file `.env` generato da `main.tf`.

---

## Grafo delle Dipendenze

```
variables.tf (nessuna dipendenza)
     |
main.tf [provider] (nessuna dipendenza runtime)
     |
     +---> network.tf
     |       |
     |       +---> data.external_network
     |       +---> hotel_net --> hotel_subnet
     |       +---> hotel_router --> router_iface (subnet)
     |       +---> bastion_fip, lb_fip (rete esterna)
     |
     +---> security.tf
     |       |
     |       +---> bastion_sg (indipendente)
     |       +---> frontend_sg (ref: bastion_sg per regola SSH)
     |       +---> backend_sg (ref: frontend_sg per regole ingress)
     |       +---> database_sg (ref: backend_sg per regola PostgreSQL)
     |
     +---> compute.tf
     |       |
     |       +---> ubuntu_jammy (Glance, indipendente)
     |       +---> data.cirros (indipendente)
     |       +---> hotel_flavor (indipendente)
     |       +---> tls_private_key --> hotel_keypair + local_sensitive_file
     |       +---> frontend[0,1] (dipende da: rete, subnet, SG frontend, immagine, flavor, keypair)
     |       +---> backend (dipende da: rete, subnet, SG backend, immagine, flavor, keypair)
     |       +---> database (dipende da: rete, subnet, SG database, immagine, flavor, keypair)
     |       +---> bastion (dipende da: rete, subnet, SG bastion, cirros, flavor, keypair)
     |       +---> bastion_fip_assoc (dipende da: bastion, bastion_fip)
     |
     +---> loadbalancer.tf
     |       |
     |       +---> hotel_lb (dipende da: subnet)
     |       +---> http_listener (dipende da: LB)
     |       +---> frontend_pool (dipende da: listener)
     |       +---> frontend_member[0,1] (dipende da: pool, frontend instances)
     |       +---> tcp_monitor (dipende da: pool)
     |       +---> lb_fip_assoc (dipende da: LB vip_port_id, lb_fip)
     |
     +---> storage.tf
     |       |
     |       +---> random_password x2 (indipendente)
     |       +---> data.current_project (indipendente)
     |       +---> media_reader, media_uploader (ruoli, indipendenti)
     |       +---> app_frontend_reader, app_frontend_uploader (utenti, dipendono da ruoli + password)
     |       +---> role assignments (dipendono da utenti + ruoli + progetto)
     |       +---> hotel_assets container (dipende da ACL con nomi utente/progetto)
     |       +---> media_seed objects (dipendono da container)
     |
     +---> main.tf [local_file.dotenv]
             |
             +---> dipende da TUTTI gli output: IP istanze, FIPs, credenziali DB,
                   password Keystone, nome container Swift, VIP LB
```

---

## Ordine di Sviluppo dei File

Lo sviluppo seguira' quest'ordine, che rispetta le dipendenze e consente
test incrementali con `terraform validate` ad ogni step:

| Fase | File | Descrizione |
|---|---|---|
| **1** | Pulizia | Rimuovi `.tf` AWS, crea `cloud-init/`, gestisci `seed_media/` |
| **2** | `variables.tf` | Dichiarazioni variabili (nessuna dipendenza) |
| **3** | `main.tf` (parziale) | Blocco `terraform`, provider (senza `local_file` per ora) |
| **4** | `cloud-init/*.yaml` | I 3 file cloud-init template |
| **5** | `network.tf` | Rete, subnet, router, floating IPs |
| **6** | `security.tf` | 4 security groups con tutte le regole |
| **7** | `compute.tf` | Immagine, flavor, keypair, 5 istanze, FIP bastion |
| **8** | `loadbalancer.tf` | LB Octavia OVN, listener, pool, members, monitor, FIP |
| **9** | `storage.tf` | Swift container, Keystone utenti/ruoli, ACL, seed media |
| **10** | `main.tf` (completamento) | Aggiunta `local_file.dotenv` con tutti i riferimenti |
| **11** | Validazione | `terraform fmt` + `terraform validate` |

---

## Convenzioni da Rispettare

Ereditate dal progetto originale (vedi `AGENTS.md`):

1. **Commenti in italiano** — mantenere la convenzione esistente
2. **Output co-locati** — ogni file contiene i propri output in fondo, separati da `# --- OUTPUTS ---`
3. **Nessun file `outputs.tf` separato**
4. **Naming risorse TF:** `snake_case` (es. `hotel_net`, `frontend_sg`)
5. **Naming risorse OpenStack:** kebab-case con prefisso `hotel-` (es. `"hotel-private-net"`, `"hotel-router"`)
6. **Tag/Metadata:** dove supportato, includere `Name` o metadata descrittivi
7. **Sezioni:** usare `# --- NOME SEZIONE ---` come separatori
8. **Nessun modulo** — tutto nel root module flat
9. **Tutte le variabili con default** — per coerenza con la convenzione del progetto

---

## Rischi e Mitigazioni

| # | Rischio | Impatto | Mitigazione |
|---|---|---|---|
| 1 | Download immagine Jammy (~700MB) lento | `terraform apply` lungo al primo run | L'immagine viene scaricata una sola volta; runs successivi la riusano |
| 2 | Risorse limitate (5 VM x 2GB = 10GB RAM su 32GB) | Possibile OOM per i servizi OpenStack | Il flavor e' gia' minimale (1 vCPU, 2GB); monitorare con `free -h` |
| 3 | Cirros ha cloud-init limitato | Il bastion non puo' eseguire script complessi | Il bastion non ha bisogno di configurazione — serve solo per SSH hop |
| 4 | `SOURCE_IP_PORT` non supportato da OVN | `terraform apply` fallisce sul pool | Fallback a `SOURCE_IP` che e' sicuramente supportato |
| 5 | MTU 1450 per virtualizzazione nested | Possibili problemi di frammentazione | Gia' configurato nel `local.conf` DevStack |
| 6 | Egress per cloud-init (download pacchetti) | Le VM non riescono a scaricare pacchetti | Il router con gateway esterno garantisce NAT per la subnet; le regole di egress lo permettono |
| 7 | Tempi di boot cloud-init | Le VM non sono pronte immediatamente dopo `terraform apply` | Cloud-init richiede 2-5 minuti; il LB health check gestira' la transizione |
| 8 | DB seeding via cloud-init non idempotente | Re-creazione VM perderebbe i dati | Accettabile per ambiente di sviluppo; lo schema SQL e' nel cloud-init |
