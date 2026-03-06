# Basic Gemini 3.1 Pro

Facciamo il classico `terraform init` e verifichiamo se la sintassi è corretta con `terraform validate`

La è.

Facendo `terraform plan` incontriamo il primo errore.

```text
╷
│ Error: Your query returned no results. Please change your search criteria and try again.
│ 
│   with data.openstack_images_image_v2.cirros,
│   on compute.tf line 7, in data "openstack_images_image_v2" "cirros":
│    7: data "openstack_images_image_v2" "cirros" {
│ 
╵
```

Andiamo a vedere in `compute.tf`.

```terraform
data "openstack_images_image_v2" "cirros" {
  name        = "cirros-0.5.2-x86_64-disk"
  most_recent = true
}
```

Ha usato una immagine cirros che è antica rispetto a quella che abbiamo noi a disposizione, aggiustiamo.


```diff
diff --git a/app-demo/terraform/output/compute.tf b/app-demo/terraform/output/compute.tf
index 885db8b..34387ab 100644
--- a/app-demo/terraform/output/compute.tf
+++ b/app-demo/terraform/output/compute.tf
@@ -5,7 +5,7 @@ resource "openstack_compute_keypair_v2" "app_key" {
 }
 
 data "openstack_images_image_v2" "cirros" {
-  name        = "cirros-0.5.2-x86_64-disk"
+  name        = "cirros-0.6.3-x86_64-disk"
   most_recent = true
 }
```

Rilanciando il plan, sembrerebbe andare tutto per il verso giusto, proviamo a fare un `terraform apply`.

I primi errori:

```text
╷
│ Error: Unable to create openstack_compute_keypair_v2 app-key: Bad request with: [POST http://192.168.1.13/compute/v2.1/os-keypairs], error message: {"badRequest": {"code": 400, "message": "Keypair data is invalid: failed to generate fingerprint"}}
│ 
│   with openstack_compute_keypair_v2.app_key,
│   on compute.tf line 2, in resource "openstack_compute_keypair_v2" "app_key":
│    2: resource "openstack_compute_keypair_v2" "app_key" {
│ 
╵
╷
│ Error: Error creating openstack_networking_network_v2: Bad request with: [POST http://192.168.1.13:9696/networking/v2.0/networks], error message: {"NeutronError": {"type": "InvalidInput", "message": "Invalid input for operation: Requested MTU is too big, maximum is 1442.", "detail": ""}}
│ 
│   with openstack_networking_network_v2.app_net,
│   on network.tf line 13, in resource "openstack_networking_network_v2" "app_net":
│   13: resource "openstack_networking_network_v2" "app_net" {
│ 
╵
```

Una cosa curiosa la troviamo: in `network.tf` troviamo:

```terraform 
resource "openstack_networking_network_v2" "app_net" {
  name           = "app_network"
  admin_state_up = true
  mtu            = 1450
}
```

Nel file di configurazione c'erano delle variabili di ambiente che esplicitavano un MTU di 1450. Tuttavia, le network che creiamo sono di tipo (di default) `Geneve` ed hanno un MTU che è di 1442, ecco perchè da questo errore.

Gli altri modelli, tuttavia, sembra che abbiano ignorato quella indicazione sull'MTU, o comunque hanno capito che non andava considerata al momento della creazione della network.

Possiamo, quindi, omettere quella linea.

```diff
diff --git a/app-demo/terraform/output/network.tf b/app-demo/terraform/output/network.tf
index dcd2474..452ec7c 100644
--- a/app-demo/terraform/output/network.tf
+++ b/app-demo/terraform/output/network.tf
@@ -13,7 +13,6 @@ resource "openstack_networking_router_v2" "router" {
 resource "openstack_networking_network_v2" "app_net" {
   name           = "app_network"
   admin_state_up = true
-  mtu            = 1450
 }
 
 resource "openstack_networking_subnet_v2" "app_subnet" {
```

Il primo errore, invece...

```terraform
# output/compute.tf
resource "openstack_compute_keypair_v2" "app_key" {
  name       = "app-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE9N92qV0mIom1V5oZlZg2iWjI8Oq6H5JqH5w8M1Jd+x5g/rN/4Qe39R1Xy5Gv6Y4f2n2/3s6U6HhE7C+R+YVf/B1mI7h/X4T+E2b5z1Q8T0A2E2A/T6X7A/C5b6Q9K5A+X3L3K2H5R+N9X8W/z1A4A/Q+T8E5Q/Q/B5V+X9L9V/Q8T+Q2H2A/T6H+R9A+R/N9A/B5V/E/Q5T/T+H/Q+A="
}
```

Qui è successo dell'incredibile: ha appena hardcodato una chiave pubblica di cui non è nota la provenienza. Il fatto che venga hardcodata la chiave pubblica, ovviamente, fa intuire che terraform non ha generato nessuna coppia di chiavi.
 
Chiedendo a Gemini 3.1 Pro direttamente attraverso OpenCode, risponde che ha inserito un valore dummy di riferimento. È interessante notare come Gemini 3.1 Pro, a valle dei prompt che ha ricevuto, pensa di essere in una fase di "planning". Opus 4.6, invece, mi è sembrato fosse molto più concreto ed orientato a fornire una soluzione orientata ad un deployment vero e proprio.

Quindi, dobbiamo modificare questo codice per far si che DevStack crei la coppia di chiavi, salvi la chiave privata localmente e che poi possa essere nota (quella pubblica) alle compute instances (come già abbiamo spesso fatto).

```diff
+   resource "tls_private_key" "hotel_ssh_key" {
+     algorithm = "RSA"
+     rsa_bits  = 4096
+   }
+   
+   resource "openstack_compute_keypair_v2" "app_key" {
+     name       = "app-key"
+     public_key = tls_private_key.hotel_ssh_key.public_key_openssh
+   }
+   
+   resource "local_sensitive_file" "private_key_pem" {
+     content         = tls_private_key.hotel_ssh_key.private_key_pem
+     filename        = var.keypair_private_key_path
+     file_permission = "0600"
+   }
+   
+   variable "keypair_private_key_path" {
+     description = "Percorso di salvataggio della chiave privata SSH"
+     type        = string
+     default     = "~/.ssh/hotel-key.pem"
+   }
```

```diff
diff --git a/app-demo/terraform/output/compute.tf b/app-demo/terraform/output/compute.tf
index 885db8b..eec195e 100644
--- a/app-demo/terraform/output/compute.tf
+++ b/app-demo/terraform/output/compute.tf
@@ -1,11 +1,6 @@
 # output/compute.tf
-resource "openstack_compute_keypair_v2" "app_key" {
-  name       = "app-key"
-  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDE9N92qV0mIom1V5oZlZg2iWjI8Oq6H5JqH5w8M1Jd+x5g/rN/4Qe39R1Xy5Gv6Y4f2n2/3s6U6HhE7C+R+YVf/B1mI7h/X4T+E2b5z1Q8T0A2E2A/T6X7A/C5b6Q9K5A+X3L3K2H5R+N9X8W/z1A4A/Q+T8E5Q/Q/B5V+X9L9V/Q8T+Q2H2A/T6H+R9A+R/N9A/B5V/E/Q5T/T+H/Q+A="
-}
-
```



Per il loadbalancer dobbiamo fare sempre lo stesso fix, e dovremmo farlo prima di creare le risorse altrimenti avremo un loadbalancer in stato `PENDING_CREATE`.

```diff
diff --git a/app-demo/terraform/output/gateway.tf b/app-demo/terraform/output/ga
diff --git a/app-demo/terraform/output/gateway.tf b/app-demo/terraform/output/ga
teway.tf
index 3023960..5d3176b 100644
--- a/app-demo/terraform/output/gateway.tf
+++ b/app-demo/terraform/output/gateway.tf
@@ -1,20 +1,21 @@
 # output/gateway.tf
 resource "openstack_lb_loadbalancer_v2" "app_lb" {
-  name          = "app_loadbalancer"
-  vip_subnet_id = openstack_networking_subnet_v2.app_subnet.id
+  name                  = "app_loadbalancer"
+  vip_subnet_id         = openstack_networking_subnet_v2.app_subnet.id
+  loadbalancer_provider = "ovn"
 }
 
 resource "openstack_lb_listener_v2" "app_listener" {
   name            = "app_listener"
-  protocol        = "HTTP"
+  protocol        = "TCP"
   protocol_port   = 80
   loadbalancer_id = openstack_lb_loadbalancer_v2.app_lb.id
 }
 
 resource "openstack_lb_pool_v2" "app_pool" {
   name        = "app_pool"
-  protocol    = "HTTP"
-  lb_method   = "ROUND_ROBIN"
+  protocol    = "TCP"
+  lb_method   = "SOURCE_IP_PORT"
   listener_id = openstack_lb_listener_v2.app_listener.id
 }
```

Per quanto riguarda il SWIFT, crea un container chiamato `app-assets` ma non carica nessun contenuto al suo interno. Inoltre, fornisce a quest ultimo una proprietà `container_read` che gli da un accesso pubblico. È come se avesse confuso il bucket che serve il sito statico con quello dedicato ai media.
Quindi, di fatto:

1. Non ha creato un container con le ACL corrette
2. Non ha creato utenti keystone con i ruoli ad hoc per dividere i compiti di lettura e scrittura (ma questo ce lo aspettavamo)
3. Non ha caricato i media come objects

Quindi, non è stato molto bravo nel portare a termine questo compito.

Per quanto riguarda le compute, questo crea due istanze con flavor `m1.nano` e immagine `cirros`. Non carica alcun `user_data`, quindi non fanno assolutamente niente. Il punto è che non si è posto nemmeno il problema di generare uno script di inizializzazione...

Le due compute create viene assegnato un security group `app_sg` il quale ha una sola regla che permette il traffico HTTP in ingresso.

Tuttavia:

1. Essendo delle cirros, ovviamente non possono fare molto
2. Il modello non ha generato alcun `user_data` da caricare (uno script, un cloud-config...) da far partire per inizializzare le macchine...

Quindi segue che le compute instance non stanno servendo NEANCHE un sito web.

Inoltre, mancano completametne gli equivalenti di RDS e dell'API Gateway, anche delle semplici VM con rispettivamente FastAPI e un Database postgres.

Inoltre, non so assolutamente perchè, ha deciso di hardcodare le credenziali di accesso in `variables.tf`

```terraform
variable "os_username" {
  description = "OpenStack username for DevStack"
  type        = string
  default     = "admin"
}

variable "os_tenant_name" {
  description = "OpenStack project/tenant name"
  type        = string
  default     = "admin"
}

variable "os_password" {
  description = "OpenStack password"
  type        = string
  default     = "secret"
}

variable "os_auth_url" {
  description = "Keystone authentication URL"
  type        = string
  default     = "http://192.168.1.13/identity/v3"
}

variable "os_region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}
```

Sembrerebbe che Gemini 3.1 Pro non abbia capito realmente che avrebbe dovuto tentare di risolvere il problema, ma piuttosto è come se stesse presentando una possibile strada, con tanti placeholder, ma che in realtà è assolutamente insufficiente.

Non ha creato neanche il LoadBalancer.

C'è bisogno di approfondire il thinking che ha fatto il modello, ed è curioso perchè gli altri modelli COMUNQUE le cose, anche se sbagliate, le hanno fatte.

