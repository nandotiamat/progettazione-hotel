# Requirements - Gemini 3.1 Pro 

Iniziamo con il classico `terraform validate`. 

Ha avuto successo..


Se facciamo un `terraform plan`, vediamo che ci viene chiesto di inserire dei valori ad un'unica variabile: `project_id`.

Nel prompt con i requisiti, abbiamo sottolineato esplicitamente di preferire l'utilizzo di un `clouds.yaml` per l'autenticazione, nonostante ciò ha ignorato questo dettaglio, quantomeno per questa specifica variabile.

Infatti, come avevamo richiesto, c'è il seguente blocco provider:

```terraform
provider "openstack" {
  # Authentication is handled seamlessly via clouds.yaml
  # Specify the cloud name from clouds.yaml using a variable
  cloud = var.openstack_cloud
}
```
La variabile `openstack_cloud` ha come default `devstack`. Quindi, implicitamente, impone l'utilizzo di un `clouds.yaml`, ma allora perchè mettere quella variabile?

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ grep -r "project_id" .
./variables.tf:variable "project_id" {
...........................................
./security.tf:  default_project_id                    = var.project_id
./security.tf:  default_project_id                    = var.project_id
./security.tf:  project_id = var.project_id
./security.tf:  project_id = var.project_id
```

In `security.tf` viene utilizzato il `project_id` per decidere in quale progetto creare il security group.

```diff
diff --git a/app-demo/terraform/output/security.tf b/app-demo/terraform/output/security.tf
index 408ab9a..1313498 100644
--- a/app-demo/terraform/output/security.tf
+++ b/app-demo/terraform/output/security.tf
@@ -1,5 +1,9 @@
 # --- IAM (Keystone) Users & Roles ---
 
+data "openstack_identity_project_v3" "current" {
+  name = "admin"
+}
+
 resource "random_password" "reader_password" {
   length  = 16
   special = true
@@ -12,14 +16,14 @@ resource "random_password" "uploader_password" {
 
 resource "openstack_identity_user_v3" "app_frontend_reader" {
   name                                  = "app_frontend_reader"
   name                                  = "app_frontend_reader"
-  default_project_id                    = var.project_id
+  default_project_id                    = data.openstack_identity_project_v3.current.id
   password                              = random_password.reader_password.result
   ignore_change_password_upon_first_use = true
 }
 
 resource "openstack_identity_user_v3" "app_frontend_uploader" {
   name                                  = "app_frontend_uploader"
-  default_project_id                    = var.project_id
+  default_project_id                    = data.openstack_identity_project_v3.current.id
   password                              = random_password.uploader_password.result
   ignore_change_password_upon_first_use = true
 }
@@ -34,13 +38,13 @@ resource "openstack_identity_role_v3" "media_uploader" {
 
 resource "openstack_identity_role_assignment_v3" "reader_assignment" {
   user_id    = openstack_identity_user_v3.app_frontend_reader.id
-  project_id = var.project_id
+  project_id = data.openstack_identity_project_v3.current.id
   role_id    = openstack_identity_role_v3.media_reader.id
 }
 
 resource "openstack_identity_role_assignment_v3" "uploader_assignment" {
   user_id    = openstack_identity_user_v3.app_frontend_uploader.id
-  project_id = var.project_id
+  project_id = data.openstack_identity_project_v3.current.id
   role_id    = openstack_identity_role_v3.media_uploader.id
 }
 
diff --git a/app-demo/terraform/output/variables.tf b/app-demo/terraform/output/variables.tf
index eb9c838..3d951be 100644
--- a/app-demo/terraform/output/variables.tf
+++ b/app-demo/terraform/output/variables.tf
@@ -4,13 +4,8 @@ variable "openstack_cloud" {
   default     = "devstack"
 }
 
-variable "project_id" {
-  description = "The default project ID for the OpenStack environment"
-  type        = string
-}
-
 variable "external_network_name" {
   description = "The name of the external network in OpenStack"
   type        = string
   default     = "public"
-}
\ No newline at end of file
+}
```

Fatto ciò e creato un `clouds.yaml` del tipo:

```yaml
clouds:
  devstack:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "admin"
      password: "secret"
      project_id: e20f12f8eeb44503af66f469e8c030aa
      project_name: "admin"
      user_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
```

Possiamo procedere con un `terraform apply`, in quanto `terraform plan` ha avuto successo.

Esploriamo un po'.

Partirei direttamente dalla parte SSH, vedo che il bastion host è stato creato con l'immagine cirros giusta. Tuttavia, non gli è stato assegnato un floating IP, facciamolo.

La cosa curiosa è la seguente:

```terraform

resource "openstack_networking_floatingip_v2" "bastion_fip" {
  pool = data.openstack_networking_network_v2.external_net.name
}

resource "openstack_networking_floatingip_associate_v2" "bastion_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
  port_id     = openstack_compute_instance_v2.bastion.network.0.port
}

```

Il floating IP viene creato, tuttavia l'associazione non avviene correttamente.

```diff
stack@devstack-4all:~/hotel/app-demo/terraform/output$ git diff
diff --git a/app-demo/terraform/output/loadbalancer.tf b/app-demo/terraform/output/loadbalancer.tf
index 2fdd017..8de8c81 100644
--- a/app-demo/terraform/output/loadbalancer.tf
+++ b/app-demo/terraform/output/loadbalancer.tf
@@ -52,7 +52,13 @@ resource "openstack_networking_floatingip_v2" "bastion_fip" {
   pool = data.openstack_networking_network_v2.external_net.name
 }
 
+data "openstack_networking_port_v2" "bastion_port" {
+  device_id  = openstack_compute_instance_v2.bastion.id
+  network_id = openstack_networking_network_v2.hotel_private_net.id
+}
+
 resource "openstack_networking_floatingip_associate_v2" "bastion_fip_assoc" {
   floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
-  port_id     = openstack_compute_instance_v2.bastion.network.0.port
+  port_id     = data.openstack_networking_port_v2.bastion_port.id
 }
```

Adesso va. Proviamo ad entrare con SSH nel bastion node.

Funziona.

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$  eval "$(ssh-agent -s)
> " 
Agent pid 31341
stack@devstack-4all:~/hotel/app-demo/terraform/output$ ssh-add ~/.ssh/hotel-key.pem
Identity added: /opt/stack/.ssh/hotel-key.pem (/opt/stack/.ssh/hotel-key.pem)
stack@devstack-4all:~/hotel/app-demo/terraform/output$  ssh -A cirros@172.24.4.160
The authenticity of host '172.24.4.160 (172.24.4.160)' can't be established.
ED25519 key fingerprint is SHA256:eQ4AThoxZ0sK3GQbNSsg/V1mU0tUaas4a56vuewIpa0.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes'
Please type 'yes', 'no' or the fingerprint: yes
Warning: Permanently added '172.24.4.160' (ED25519) to the list of known hosts.
$ 
```

![alt text](image.png)

Dando una occhiata ai security groups e rules, vanno bene.
Proviamo il load balancer.

Non sta funzionando perchè non stanno funzionando le VM! 

Perchè al momento della creazione della subnet, non ha esplicitato i dns:

```diff
diff --git a/app-demo/terraform/output/network.tf b/app-demo/terraform/output/network.tf
index 32f6009..a32a685 100644
--- a/app-demo/terraform/output/network.tf
+++ b/app-demo/terraform/output/network.tf
@@ -10,6 +10,7 @@ resource "openstack_networking_subnet_v2" "hotel_private_subnet" {
   network_id = openstack_networking_network_v2.hotel_private_net.id
   cidr       = "10.0.1.0/24"
   ip_version = 4
+  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
 }
'
```

Adesso funziona.

```text
[[0;1;31m*[0m[0;31m*    [0m] (2 of 3) A start job is running for���e Resolution (1min 44s / 3min 12s)
M[K[[0m[0;31m*     [0m] (2 of 3) A start job is running for���e Resolution (1min 45s / 3min 12s)
M[K[[0;32m  OK  [0m] Finished [0;1;39mWait for Network to be Configured[0m.
[K         Starting [0;1;39mCloud-init: Network Stage[0m...
[[0;32m  OK  [0m] Started [0;1;39mNetwork Name Resolution[0m.
[[0;32m  OK  [0m] Reached target [0;1;39mNetwork[0m.
[[0;32m  OK  [0m] Reached target [0;1;39mHost and Network Name Lookups[0m.
```

Il container non sta caricando i media, però ha correttamente creato il container, specificando nei permessi container_read `app_frontend_reader` e `app_frontend_uploader`.

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.130
<!DOCTYPE html>
<html>
<head>
    <title>Hotel App Demo</title>
</head>
<body>
    <h1>Welcome to the Hotel Application!</h1>
    <p>Served from the OpenStack Frontend.</p>
</body>
</html>
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.130
<!DOCTYPE html>
<html>
<head>
    <title>Hotel App Demo</title>
</head>
<body>
    <h1>Welcome to the Hotel Application!</h1>
    <p>Served from the OpenStack Frontend.</p>
</body>
</html>
```

Adesso il loadbalancer sta funzionando, tutavia non è stato abbastanza sveglio da fare in modo che i frontend (per debugging) servissero delle pagine leggermente diverse.

Andrebbero caricati i media nel container.

Proviamo a debuggare i ruoli `app_frontend_reader` e `app_frontend_uploader`.

```
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud reader container show hotel-assets
+----------------+---------------------------------------+
| Field          | Value                                 |
+----------------+---------------------------------------+
| account        | AUTH_e20f12f8eeb44503af66f469e8c030aa |
| bytes_used     | 16                                    |
| container      | hotel-assets                          |
| object_count   | 1                                     |
| storage_policy | Policy-0                              |
+----------------+---------------------------------------+
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud uploader object create hotel-assets test.txt
+----------+--------------+----------------------------------+
| object   | container    | etag                             |
+----------+--------------+----------------------------------+
| test.txt | hotel-assets | 5d74727d50368c4741d76989586d91de |
+----------+--------------+----------------------------------+
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud devstack object delete hotel-assets test.txt
```

```diff
diff --git a/app-demo/terraform/output/storage.tf b/app-demo/terraform/output/storage.tf
index 3763bda..88c8554 100644
--- a/app-demo/terraform/output/storage.tf
+++ b/app-demo/terraform/output/storage.tf
@@ -4,8 +4,8 @@ resource "openstack_objectstorage_container_v1" "hotel_assets" {
   name = "hotel-assets"
 
   # Configure ACLs based on Keystone roles created in step 2
-  container_read  = "app_frontend_reader"
-  container_write = "app_frontend_uploader"
+  container_read  = "media_reader"
+  container_write = "media_uploader"
 }
```

Anzichè mettere i ruoli nelle ACL ha messo i nomi degli utenti...

```yaml
clouds:
  devstack:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "admin"
      password: "secret"
      project_id: e20f12f8eeb44503af66f469e8c030aa
      project_name: "admin"
      user_domain_name: "Default"
    region_name: "RegionOne"
  reader:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "app_frontend_reader"
      password: "Ab)&xW[K+FJAFGeJ"  
      project_id: e20f12f8eeb44503af66f469e8c030aa
      project_name: "admin"
      user_domain_name: "Default"
    region_name: "RegionOne"
  uploader:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "app_frontend_uploader"
      password: "CU8TvJ%8d?SNn@z=" 
      project_id: e20f12f8eeb44503af66f469e8c030aa
      project_name: "admin"
      user_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
``` 

questo è il clouds.yaml aggiornato, prendendo le password ricavate dal file `.env`.
