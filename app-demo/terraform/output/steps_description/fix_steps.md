# Basic GPT5.2 review

Lanciando `terraform plan`, mi chiede di inserire il valore di alcune variabili:

* `flavor_name`: chiede il nome del flavor da usare per i compute node, che dice esplicitamente deve esistere in Nova: non si è preoccupato minimamente di scegliere un flavor oppure di crearmi un flavor apposito. Per debuggare provo a mettere `ds1G`.
* `image_name`: fa la stessa cosa con l'immagine da caricare nella VM. Non si è posto il problema neanche qui, per debuggare mettiamo la `cirros` disponibile, sapendo che poi andrebbe comunque cambiata (`cirros-0.6.3-x86_64-disk`).
* `keypair_name`: non si è preso la briga NEANCHE di crearmi una coppia di chiavi SSH!!!!!! Ho creato una chiave SSH su Horizon chiamata `hotel_key`. Al momento della creazione, sull'host viene scaricata la chiave privata `hotel_key.pem`.
* `auth_url`: mi chiede addirittura l'openstack auth url... dovrebbe essere in grado di ricavarlo essendo noto l'host_ip (dal `local.conf`) e dalla versione di openstack installata sul target node. Passiamoglielo.
* `password`: password dell'utente devstack che dovrebbe interagire con devstack per create tutte le risorse definite nel Terraform. Qui il modello sta facendo un qualcosa che non avrebbe dovuto fare, perchè tutte queste informazioni sono definite proprio a livello di `clouds.yaml` o comunque, in fase di sviluppo locale (devstack) è possibile fare `source openrc admin admin` per caricare le variabili d'ambiente con i rispettivi valori. Diamogli la password (`secret`)
* `project_name`: `admin` 
* `username`: `admin`

Ma a parte tutto ciò: a me interessa avere un Terraform che mi permette di fare il provisioning dell'infrastruttura! Tutti questi sono componenti che devo poter creare richiedendo un apply di un piano Terraform! Non dovrei crearli io!

Usare variabili per tutte queste cose è doppiamente sbagliato, perchè dobbiamo considerare che, anche se decidiamo di creare le risorse direttamente con terraform (DOVREMMO), le variabili non possono assumere valori di default usando campi delle risorse...

Siamo partiti malino.

Lanciamo il `terraform apply`, già vedo che il load balancer non riesce a crearsi.

```text
openstack_lb_loadbalancer_v2.app: Still creating... [00m30s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [00m40s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [00m50s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [01m00s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [01m10s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [01m20s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [01m30s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [01m40s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [01m50s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [02m00s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [02m10s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [02m20s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [02m30s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [02m40s elapsed]
```

Immagino che anche lui sia caduto nel problema di Octavia con provider `OVN`.

Infatti, da Horizon si vede come il provider del load balancer è impostato su `amphora`. Infatti lancia anche una VM con immagine `amphora-x64-haproxy` che però è inutile in questo caso.

I container swift li crea ma sono vuoti, probabilmente perchè non ha trovato i file (basterebbe un symlink o copiare i file nella directory in cui lavora il modello)

Da Horizon sembrerebbe che non abbia creato alcun utente, ruolo (per Swift). TODO: verifica codice terraform.

Ha creato due SG `hotel-app-db` e `hotel-app-backend`, ci sono due nodi compute di backend ed uno di DB. Probabilmente l'API Gateway non è stato sostituito neanche con una semplice VM con FastAPI o qualcosa del genere, sembrerebbe.

Le regole attaccate ai security group sono minimali e dovrebbero funzionare (SSH ingress e per i backend TCP su 8000 e db TCP su 5432 per `postgres`).

Dopo 10 minuti di attesa:

```text

openstack_lb_loadbalancer_v2.app: Still creating... [09m01s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [09m11s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [09m21s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [09m31s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [09m41s elapsed]
openstack_lb_loadbalancer_v2.app: Still creating... [09m51s elapsed]
╷
│ Error: Error waiting for loadbalancer 4a1eeb1f-4211-4393-84b9-dc1780a20652 to become ACTIVE: context deadline exceeded
│ 
│   with openstack_lb_loadbalancer_v2.app,
│   on lb.tf line 1, in resource "openstack_lb_loadbalancer_v2" "app":
│    1: resource "openstack_lb_loadbalancer_v2" "app" {
│ 
╵
╷
│ Error: Error creating openstack_networking_secgroup_rule_v2: Expected HTTP response code [201 202] when accessing [POST http://192.168.1.13:9696/networking/v2.0/security-group-rules], but got 409 instead: {"NeutronError": {"type": "SecurityGroupRuleExists", "message": "Security group rule already exists. Rule id is 2a9bf9b1-96aa-4850-83b4-6a5f168eaf55.", "detail": ""}}
│ 
│   with openstack_networking_secgroup_rule_v2.backend_egress_all,
│   on security.tf line 26, in resource "openstack_networking_secgroup_rule_v2" "backend_egress_all":
│   26: resource "openstack_networking_secgroup_rule_v2" "backend_egress_all" {
│ 
╵
╷
│ Error: Error creating openstack_networking_secgroup_rule_v2: Expected HTTP response code [201 202] when accessing [POST http://192.168.1.13:9696/networking/v2.0/security-group-rules], but got 409 instead: {"NeutronError": {"type": "SecurityGroupRuleExists", "message": "Security group rule already exists. Rule id is 572d3da4-b29e-47b5-b319-eeebb8fc4378.", "detail": ""}}
│ 
│   with openstack_networking_secgroup_rule_v2.db_egress_all,
│   on security.tf line 57, in resource "openstack_networking_secgroup_rule_v2" "db_egress_all":
│   57: resource "openstack_networking_secgroup_rule_v2" "db_egress_all" {
│ 
╵
```

Iniziamo a fare fix nel codice terraform, dobbiamo:

1. Rimuovere le variabili ricavabili da un `clouds.yaml` o banalmente facendo il source di `openrc` (DevStack).
2. Creare le risorse (keypairs, immagine...) che il modello non si è preso la responsabilità di creare.
3. Aggiungere un Flavor adatto alla macchina target.
4. Fare in modo che il load balancer funzioni a livello TCP.
5. Rimuovere le rules già esistenti dei security groups.

Il punto è: se il modello non ha scelto neanche un'immagine (o comunque non mi ha comunicato quale avrei dovuto usare), in base a cosa ha creato quei `user_data`?

Ha creato dei file `bash` che comunque richiedono tool come `apt-get`, cirros chiaramente non va bene. Proviamo l'immagine `Ubuntu cloud` solita che stiamo usando.

Presentiamo un po' le diff con le modifiche effettuate.

Anzitutto sono stati aggiunti i seguenti 3 files: `flavor.tf`, `image.tf`, `key.tf`.

```terraform
# flavor.tf
resource "openstack_compute_flavor_v2" "hotel_flavor" {
  name      = "hotel_flavor"
  vcpus     = 1
  ram       = 2048
  disk      = 10
  is_public = true
}
```

```terraform
# image.tf
resource "openstack_images_image_v2" "ubuntu_jammy" {
  name             = "ubuntu-jammy-cloudimg"
  image_source_url = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "public"
}
```

```terraform
# key.tf
resource "tls_private_key" "hotel_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "openstack_compute_keypair_v2" "hotel_keypair" {
  name       = "hotel-keypair"
  public_key = tls_private_key.hotel_ssh_key.public_key_openssh
}

# Salvataggio della chiave privata su filesystem locale
resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.hotel_ssh_key.private_key_pem
  filename        = var.keypair_private_key_path
  file_permission = "0600"
}

variable "keypair_private_key_path" {
  description = "Percorso di salvataggio della chiave privata SSH"
  type        = string
  default     = "./.ssh/hotel-key.pem"
}
```

Successivamente, ecco le diff:

```diff
diff --git a/app-demo/terraform/output/compute_backend.tf b/app-demo/terraform/output/compute_backend.tf
index eacf5e2..35af990 100644
--- a/app-demo/terraform/output/compute_backend.tf
+++ b/app-demo/terraform/output/compute_backend.tf
@@ -1,18 +1,14 @@
-data "openstack_images_image_v2" "image" {
-  name        = var.image_name
-  most_recent = true
-}
-
 data "openstack_compute_flavor_v2" "flavor" {
-  name = var.flavor_name
+  name = openstack_compute_flavor_v2.hotel_flavor.name
 }
 
 resource "openstack_compute_instance_v2" "backend" {
   count     = var.backend_count
   name      = "${var.app_name}-backend-${count.index}"
-  image_id  = data.openstack_images_image_v2.image.id
+  image_id  = openstack_images_image_v2.ubuntu_jammy.id
   flavor_id = data.openstack_compute_flavor_v2.flavor.id
-  key_pair  = var.keypair_name
+  key_pair  = openstack_compute_keypair_v2.hotel_keypair.name
+
 
   security_groups = [
     openstack_networking_secgroup_v2.backend.name,
diff --git a/app-demo/terraform/output/compute_db.tf b/app-demo/terraform/output/compute_db.tf
index 36bd274..97512d7 100644
--- a/app-demo/terraform/output/compute_db.tf
+++ b/app-demo/terraform/output/compute_db.tf
@@ -16,9 +16,9 @@ locals {
 
 resource "openstack_compute_instance_v2" "db" {
   name      = "${var.app_name}-db"
-  image_id  = data.openstack_images_image_v2.image.id
+  image_id  = openstack_images_image_v2.ubuntu_jammy.id
   flavor_id = data.openstack_compute_flavor_v2.flavor.id
-  key_pair  = var.keypair_name
+  key_pair  = openstack_compute_keypair_v2.hotel_keypair.name
   user_data = local.db_user_data
 
   security_groups = [
diff --git a/app-demo/terraform/output/lb.tf b/app-demo/terraform/output/lb.tf
index e835ae8..cd36466 100644
--- a/app-demo/terraform/output/lb.tf
+++ b/app-demo/terraform/output/lb.tf
@@ -1,29 +1,29 @@
 resource "openstack_lb_loadbalancer_v2" "app" {
...skipping...
-
-variable "openstack_password" {
-  type        = string
-  description = "OpenStack user password."
-  sensitive   = true
-}
-
-variable "openstack_project_name" {
-  type        = string
-  description = "OpenStack project (tenant) name."
-}
-
-variable "openstack_user_domain_name" {
-  type        = string
-  description = "OpenStack user domain name."
-  default     = "Default"
-}
-
-variable "openstack_project_domain_name" {
-  type        = string
-  description = "OpenStack project domain name."
-  default     = "Default"
-}
-
 variable "external_network_name" {
   type        = string
   description = "Name of the external (public) network used for router gateway and floating IPs."
@@ -66,21 +27,6 @@ variable "network_dns_nameservers" {
   default     = ["1.1.1.1", "8.8.8.8"]
 }
 
-variable "image_name" {
-  type        = string
-  description = "Image name for instances (must exist in Glance)."
-}
-
-variable "flavor_name" {
-  type        = string
-  description = "Flavor name for instances (must exist in Nova)."
-}
-
-variable "keypair_name" {
-  type        = string
-  description = "Nova keypair name used for SSH access to instances."
-}
-
 variable "ssh_ingress_cidr" {
   type        = string
   description = "CIDR allowed to SSH to instances (set to your workstation/VPN range)."
...skipping...
-
-variable "openstack_password" {
-  type        = string
-  description = "OpenStack user password."
-  sensitive   = true
-}
-
-variable "openstack_project_name" {
-  type        = string
-  description = "OpenStack project (tenant) name."
-}
-
-variable "openstack_user_domain_name" {
-  type        = string
-  description = "OpenStack user domain name."
-  default     = "Default"
-}
-
-variable "openstack_project_domain_name" {
-  type        = string
-  description = "OpenStack project domain name."
-  default     = "Default"
-}
-
 variable "external_network_name" {
   type        = string
   description = "Name of the external (public) network used for router gateway and floating IPs."
@@ -66,21 +27,6 @@ variable "network_dns_nameservers" {
   default     = ["1.1.1.1", "8.8.8.8"]
 }
 
-variable "image_name" {
-  type        = string
-  description = "Image name for instances (must exist in Glance)."
-}
-
-variable "flavor_name" {
-  type        = string
-  description = "Flavor name for instances (must exist in Nova)."
-}
-
-variable "keypair_name" {
-  type        = string
-  description = "Nova keypair name used for SSH access to instances."
-}
-
 variable "ssh_ingress_cidr" {
   type        = string
   description = "CIDR allowed to SSH to instances (set to your workstation/VPN range)."
...skipping...
-
-variable "openstack_password" {
-  type        = string
-  description = "OpenStack user password."
-  sensitive   = true
-}
-
-variable "openstack_project_name" {
-  type        = string
-  description = "OpenStack project (tenant) name."
-}
-
-variable "openstack_user_domain_name" {
-  type        = string
-  description = "OpenStack user domain name."
-  default     = "Default"
-}
-
-variable "openstack_project_domain_name" {
-  type        = string
-  description = "OpenStack project domain name."
-  default     = "Default"
-}
-
 variable "external_network_name" {
   type        = string
   description = "Name of the external (public) network used for router gateway and floating IPs."
@@ -66,21 +27,6 @@ variable "network_dns_nameservers" {
   default     = ["1.1.1.1", "8.8.8.8"]
 }
 
-variable "image_name" {
-  type        = string
-  description = "Image name for instances (must exist in Glance)."
-}
-
-variable "flavor_name" {
-  type        = string
-  description = "Flavor name for instances (must exist in Nova)."
-}
-
-variable "keypair_name" {
-  type        = string
-  description = "Nova keypair name used for SSH access to instances."
-}
-
 variable "ssh_ingress_cidr" {
   type        = string
   description = "CIDR allowed to SSH to instances (set to your workstation/VPN range)."
``` 

In questa situazione, ora, il `terraform plan` non chiede di inserire il valore di nessuna variabile, e da `success`. Ora bisogna capire cosa succede nel `terraform apply`.

Il `terraform output` è il seguente:

```text
aws_stack_inventory = {
  "compute" = {
    "features" = [
      "application load balancer",
      "target group + listener",
      "launch template",
      "autoscaling group",
      "CloudWatch alarm + scaling policy",
      "manual debug EC2 instance (port 8000)",
    ]
    "files" = [
      "compute.tf",
    ]
  }
  "database" = {
    "features" = [
      "RDS Postgres",
      "subnet group",
      "schema initialization via null_resource + local-exec (psql)",
    ]
    "files" = [
      "storage.tf",
    ]
  }
  "iam" = {
    "features" = [
      "IAM role/policy/profile for backend",
      "S3 media bucket access",
    ]
    "files" = [
      "iam.tf",
    ]
  }
  "identity_and_api" = {
    "features" = [
      "Cognito user pool/client/domain/groups",
      "API Gateway v2 HTTP API",
      "JWT authorizer (Cognito)",
      "HTTP proxy integration to backend:8000",
    ]
    "files" = [
      "identity.tf",
      "gateway.tf",
    ]
  }
  "local_integration" = {
    "features" = [
      "AWS provider configured for LocalStack endpoints",
      "local_file writes /config/localstack.env for other components",
    ]
    "files" = [
      "main.tf",
    ]
  }
  "networking" = {
    "features" = [
      "VPC",
      "public/private subnets",
      "internet gateway",
      "route tables",
      "Route53 private zone",
      "LocalStack default VPC/subnets/SG references for debug",
    ]
    "files" = [
      "network.tf",
    ]
  }
  "security" = {
    "features" = [
      "security groups for ALB, EC2, DB",
      "extra ingress rules on default SG for LocalStack port mapping",
    ]
    "files" = [
      "security.tf",
    ]
  }
  "storage" = {
    "features" = [
      "S3 frontend bucket (static website)",
      "S3 media bucket",
      "S3 object seeding (seed_media/*)",
      "CloudFront distribution (SPA-friendly error responses)",
    ]
    "files" = [
      "storage.tf",
      "frontend_distribution.tf",
    ]
  }
}
backend_instance_ipv4 = [
  "10.50.0.130",
  "10.50.0.189",
]
capability_matrix = {
  "autoscaling" = {
    "aws" = [
      "ASG",
      "launch template",
      "CloudWatch alarms/policies",
    ]
    "notes" = "DevStack does not enable Senlin/Aodh by default; emulate with count and document manual scaling."
    "openstack" = [
      "Fixed instance count",
    ]
    "status" = "workaround"
  }
  "cdn" = {
    "aws" = [
      "CloudFront distribution",
    ]
    "notes" = "No CDN in base DevStack; omit. Optional proxy/cache VM is out of scope for this port."
    "openstack" = []
    "status" = "omitted"
  }
  "dns_private_zone" = {
    "aws" = [
      "Route53 private hosted zone",
    ]
    "notes" = "Designate is typically not enabled in DevStack; rely on outputs and/or /etc/hosts."
    "openstack" = []
    "status" = "omitted"
  }
  "identity_and_api_gateway" = {
    "aws" = [
      "Cognito",
      "API Gateway v2 HTTP API + JWT authorizer",
    ]
    "notes" = "No direct equivalents in this DevStack profile. Route through Octavia LB; auth becomes app responsibility."
    "openstack" = []
    "status" = "omitted"
  }
  "load_balancing" = {
    "aws" = [
      "ALB",
    ]
    "notes" = "Use an HTTP listener/pool with members = backend instances. Floating IP for VIP for external access."
    "openstack" = [
      "Octavia load balancer",
    ]
    "status" = "supported"
  }
  "managed_database" = {
    "aws" = [
      "RDS Postgres",
    ]
    "notes" = "Trove is not enabled; provision a DB VM and initialize via cloud-init."
    "openstack" = [
      "Postgres on Nova VM",
    ]
    "status" = "workaround"
  }
  "networking" = {
    "aws" = [
      "VPC",
      "subnets",
      "route tables",
      "internet gateway",
    ]
    "notes" = "Model as one tenant network/subnet and a router to the external network."
    "openstack" = [
      "Neutron network",
      "Neutron subnet",
      "Neutron router + interface",
      "Neutron router external gateway",
    ]
    "status" = "supported"
  }
  "object_storage" = {
    "aws" = [
      "S3 buckets",
      "S3 objects",
    ]
    "notes" = "Create containers for frontend/media; optional object upload via Terraform if local seed path exists."
    "openstack" = [
      "Swift containers",
      "Swift objects",
    ]
    "status" = "supported"
  }
  "security_groups" = {
    "aws" = [
      "EC2 security groups",
    ]
    "notes" = "Use SGs for backend and DB; restrict access by source SG."
    "openstack" = [
      "Neutron security groups + rules",
    ]
    "status" = "supported"
  }
}
db_instance_ipv4 = "10.50.0.13"
env_file = "../config/devstack.env"
lb_floating_ip = "172.24.4.81"
lb_http_endpoint = "http://172.24.4.81:80"
mapping_hints = {
  "ALB" = "Octavia LB"
  "ASG/CloudWatch" = "Fixed instance count (manual scaling)"
  "CloudFront" = "Omit (optional proxy/caching layer)"
  "Cognito/APIGW" = "Direct LB routing + app-level auth"
  "RDS" = "Postgres on Nova VM (or Trove if enabled)"
  "Route53" = "Omit or Designate (if enabled)"
  "S3" = "Swift"
  "Security Groups" = "Neutron security groups/rules"
  "VPC/Subnets/Routes" = "Neutron network/subnet/router"
}
not_one_to_one_in_devstack = [
  "Cognito user pools/groups and managed JWT authorizer behavior",
  "API Gateway v2 routing/authorizers/integrations",
  "CloudFront CDN distribution",
  "Route53 private hosted zone (unless Designate is enabled)",
  "RDS managed Postgres (unless Trove is enabled)",
  "ASG + CloudWatch alarms-based autoscaling (unless Senlin/Aodh are enabled)",
]
swift_containers = {
  "frontend" = "hotel-app-frontend"
  "media" = "hotel-app-media"
}
target_file_layout = [
  {
    "path" = "provider.tf"
    "purpose" = "OpenStack provider configuration; optional clouds.yaml support; required providers block."
  },
  {
    "path" = "variables.tf"
    "purpose" = "All inputs (auth, image/flavor/keypair, network names/CIDRs, counts, ports) with validation."
  },
  {
    "path" = "network.tf"
    "purpose" = "Neutron tenant network/subnet, router, router interface, external gateway; optionally floating IP pool lookup."
  },
  {
    "path" = "security.tf"
    "purpose" = "Neutron security groups and rules for backend, DB, optional SSH ingress."
  },
  {
    "path" = "compute_backend.tf"
    "purpose" = "Backend instance group via count; ports for app; attach SG; cloud-init for app runtime."
  },
  {
    "path" = "compute_db.tf"
    "purpose" = "DB instance (Postgres) + cloud-init initialization; optional Cinder volume."
  },
  {
    "path" = "lb.tf"
    "purpose" = "Octavia LB: loadbalancer, listener, pool, members, health monitor; floating IP association for VIP."
  },
  {
    "path" = "swift.tf"
    "purpose" = "Swift containers for frontend/media; optional objects upload if seed paths exist."
  },
  {
    "path" = "env_file.tf"
    "purpose" = "Generate a dotenv-style file with endpoints/IDs for downstream components (replaces /config/localstack.env)."
  },
  {
    "path" = "outputs.tf"
    "purpose" = "Expose LB endpoint, instance IPs, DB endpoint, Swift container names, and env file path."
  },
]
```

![alt text](image.png)
![alt text](image-1.png)

Partendo subito con il test SSH, vediamo come:
1. Non è stato generato ALCUN floating IP, se non al LOAD BALANCER, che è quindi l'unico ad avere un floating IP.
2. I nodi compute, invece, hanno solamente un IP nella subnet privata, non raggiungibile dall'esterno

Dal nodo target, su cui gira DevStack, come faccio ad entrare con SSH nelle macchine? Non posso, mi serve come minimo un floating IP.

Dovrei utilizzare un bastion host per ridurre al minimo l'esposizione verso l'esterno delle macchine compute. Tuttavia, per questioni di praticità (stiamo solo esplorando cosa fa il modello, cosa comporta fixare l'output del modello...), lo assegnamo un floating IP ad uno dei due backend, tanto la ssh rule è su 0.0.0.0/0.

```diff
+
+resource "openstack_networking_floatingip_v2" "backend_fip" {
+  pool = var.external_network_name
+}
+
+data "openstack_networking_port_v2" "backend_port" {
+  device_id  = openstack_compute_instance_v2.backend[0].id
+  network_id = openstack_networking_network_v2.app_net.id
+}
+
+resource "openstack_networking_floatingip_associate_v2" "backend_fip_assoc" {
+  floating_ip = openstack_networking_floatingip_v2.backend_fip.address
+  port_id     = data.openstack_networking_port_v2.backend_port.id
+}
+
```

Siamo dentro, proviamo ad entrare da questo nodo nelle altre macchine (dovrebbe andare)

Con ssh riesco adesso, a partire dal nodo con il floating IP, entrare dentro le VM.

Non ci soffermiamo molto sul nodo con il DB, non ci interessa molto della fase di deploy del database.

Vediamo se il loadbalancer sta funzionando.

Ovviamente no, il motivo però è semplice (ricoridamoci che all'inizio aveva sbagliato totalmente, il motivo per cui ora non funziona è una conseguenza del fatto che non ha capito cosa comporta avere ovn come provider)

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.81
ok
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.81
ok
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.81
ok
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.81
ok
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.81
ok
```

```diff
diff --git a/app-demo/terraform/output/security.tf b/app-demo/terraform/output/security.tf
index 7e2ec59..2857ee6 100644
--- a/app-demo/terraform/output/security.tf
+++ b/app-demo/terraform/output/security.tf
@@ -9,7 +9,7 @@ resource "openstack_networking_secgroup_rule_v2" "backend_ingress_http" {
   protocol          = "tcp"
   port_range_min    = var.backend_app_port
   port_range_max    = var.backend_app_port
-  remote_ip_prefix  = var.network_cidr
+  remote_ip_prefix  = "0.0.0.0/0" 
   security_group_id = openstack_networking_secgroup_v2.backend.id
 }
 
@@ -19,15 +19,10 @@ resource "openstack_networking_secgroup_rule_v2" "backend_ingress_ssh" {
   protocol          = "tcp"
   port_range_min    = 22
   port_range_max    = 22
-  remote_ip_prefix  = var.ssh_ingress_cidr
+  remote_ip_prefix  = "0.0.0.0/0" 
   security_group_id = openstack_networking_secgroup_v2.backend.id
 }
```

Di swift non c'è niente da debuggare perchè non ha fatto NIENTE se non:

```terraform
stack@devstack-4all:~/hotel/app-demo/terraform/output$ cat swift.tf 
resource "openstack_objectstorage_container_v1" "frontend" {
  name = "${var.app_name}-frontend"
}

resource "openstack_objectstorage_container_v1" "media" {
  name = "${var.app_name}-media"
}
```

Chiaramente, li crea. Ma sono vuoti, senza ACL...deludente...

Penso abbiamo raccolto abbastanza informazioni
