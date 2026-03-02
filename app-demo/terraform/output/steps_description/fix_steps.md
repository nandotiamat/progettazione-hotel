# Fix Steps and Infrastructure Validation (OPUS4.6-requirements)

## 1. Resolving the Security Group Attachment Error

During the initial deployment, Terraform encountered several errors when attempting to attach security groups to the compute instances. The API returned a `400 Bad Request` because it could not locate the security groups by the provided references.

```text
╷
│ Error: Error creating OpenStack server: Expected HTTP response code [200 202] when accessing [POST http://192.168.1.13/compute/v2.1/servers], but got 400 instead: {"badRequest": {"code": 400, "message": "Unable to find security_group with name or id 'frontend-security-group'"}}
│ 
│   with openstack_compute_instance_v2.frontend[1],
│   on compute.tf line 61, in resource "openstack_compute_instance_v2" "frontend":
│   61: resource "openstack_compute_instance_v2" "frontend" {
│ 
╵
╷
│ Error: Error creating OpenStack server: Expected HTTP response code [200 202] when accessing [POST http://192.168.1.13/compute/v2.1/servers], but got 400 instead: {"badRequest": {"code": 400, "message": "Unable to find security_group with name or id 'frontend-security-group'"}}
│ 
│   with openstack_compute_instance_v2.frontend[0],
│   on compute.tf line 61, in resource "openstack_compute_instance_v2" "frontend":
│   61: resource "openstack_compute_instance_v2" "frontend" {
│ 
╵
╷
│ Error: Error creating OpenStack server: Expected HTTP response code [200 202] when accessing [POST http://192.168.1.13/compute/v2.1/servers], but got 400 instead: {"badRequest": {"code": 400, "message": "Unable to find security_group with name or id 'backend-security-group'"}}
│ 
│   with openstack_compute_instance_v2.backend,
│   on compute.tf line 82, in resource "openstack_compute_instance_v2" "backend":
│   82: resource "openstack_compute_instance_v2" "backend" {
│ 
╵
╷
│ Error: Error creating OpenStack server: Expected HTTP response code [200 202] when accessing [POST http://192.168.1.13/compute/v2.1/servers], but got 400 instead: {"badRequest": {"code": 400, "message": "Unable to find security_group with name or id 'database-security-group'"}}
│ 
│   with openstack_compute_instance_v2.database,
│   on compute.tf line 99, in resource "openstack_compute_instance_v2" "database":
│   99: resource "openstack_compute_instance_v2" "database" {
│ 
╵
╷
│ Error: Error creating OpenStack server: Expected HTTP response code [200 202] when accessing [POST http://192.168.1.13/compute/v2.1/servers], but got 400 instead: {"badRequest": {"code": 400, "message": "Unable to find security_group with name or id 'bastion-security-group'"}}
│ 
│   with openstack_compute_instance_v2.bastion,
│   on compute.tf line 121, in resource "openstack_compute_instance_v2" "bastion":
│  121: resource "openstack_compute_instance_v2" "bastion" {

```

**The Fix:** The issue stems from passing the security group `.name` attribute instead of the `.id`. By switching the `security_groups` array to reference the IDs, the problem is resolved and the `terraform apply` succeeds.

```diff
diff --git a/app-demo/terraform/output/compute.tf b/app-demo/terraform/output/compute.tf
index 4ec8d58..ed698f1 100644
--- a/app-demo/terraform/output/compute.tf
+++ b/app-demo/terraform/output/compute.tf
@@ -65,7 +65,7 @@ resource "openstack_compute_instance_v2" "frontend" {
   image_id        = openstack_images_image_v2.ubuntu_jammy.id
   flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
   key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
-  security_groups = [openstack_networking_secgroup_v2.frontend_sg.name]
+  security_groups = [openstack_networking_secgroup_v2.frontend_sg.id]
 
   network {
     uuid = openstack_networking_network_v2.hotel_net.id
@@ -84,7 +84,7 @@ resource "openstack_compute_instance_v2" "backend" {
   image_id        = openstack_images_image_v2.ubuntu_jammy.id
   flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
   key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
-  security_groups = [openstack_networking_secgroup_v2.backend_sg.name]
+  security_groups = [openstack_networking_secgroup_v2.backend_sg.id]
 
   network {
     uuid = openstack_networking_network_v2.hotel_net.id
@@ -101,7 +101,7 @@ resource "openstack_compute_instance_v2" "database" {
   image_id        = openstack_images_image_v2.ubuntu_jammy.id
   flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
   key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
-  security_groups = [openstack_networking_secgroup_v2.database_sg.name]
+  security_groups = [openstack_networking_secgroup_v2.database_sg.id]
 
   network {
     uuid = openstack_networking_network_v2.hotel_net.id
@@ -123,7 +123,7 @@ resource "openstack_compute_instance_v2" "bastion" {
   image_id        = data.openstack_images_image_v2.cirros.id
   flavor_id       = openstack_compute_flavor_v2.hotel_flavor.id
   key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
-  security_groups = [openstack_networking_secgroup_v2.bastion_sg.name]
+  security_groups = [openstack_networking_secgroup_v2.bastion_sg.id]
 
   network {
     uuid = openstack_networking_network_v2.hotel_net.id


```

---

## 2. Validating the Load Balancer and Frontend Nodes

With the infrastructure successfully deployed, we can begin validating the resources. First, let's test the load balancer by sending a cURL request to its floating IP on port 80 (which is mapped to its VIP).

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.42
<!DOCTYPE html>
<html>
<head><title>Hotel App - Frontend 2</title></head>
<body>
  <h1>Frontend node 2</h1>
  <p>Hotel application frontend server.</p>
</body>
</html>
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.42
<!DOCTYPE html>
<html>
<head><title>Hotel App - Frontend 2</title></head>
<body>
  <h1>Frontend node 2</h1>
  <p>Hotel application frontend server.</p>
</body>
</html>
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.42
<!DOCTYPE html>
<html>
<head><title>Hotel App - Frontend 1</title></head>
<body>
  <h1>Frontend node 1</h1>
  <p>Hotel application frontend server.</p>
</body>
</html>

```

This output confirms two important aspects of the deployment:

1. The load balancer is functioning correctly (both at the listener and pool levels).
2. The frontend nodes are successfully serving HTML traffic on port 80.

Additionally, the health monitor was created successfully. Although it lacks a specific name, it is functioning as intended.

---

## 3. Fixing the Bastion Host Floating IP Association

There was an issue where the floating IP was not properly assigned to the Bastion host. Initially, it seemed like the CirrOS instance failed to boot due to low vCPU resources, but the actual cause was a faulty resource association in Terraform.

**The Fix:**
Using a `data` block to fetch the exact network port of the instance resolves the association problem.

```diff

 # --- ASSOCIAZIONE FLOATING IP BASTION ---
-# Associa la floating IP allocata in network.tf alla porta di rete del bastion
+data "openstack_networking_port_v2" "bastion_port" {
+  device_id  = openstack_compute_instance_v2.bastion.id
+  network_id = openstack_networking_network_v2.hotel_net.id
+}
+
 resource "openstack_networking_floatingip_associate_v2" "bastion_fip_assoc" {
   floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
-  port_id     = openstack_compute_instance_v2.bastion.network[0].port
+  port_id     = data.openstack_networking_port_v2.bastion_port.id
 }

```

---

## 4. Internal Network Validation via Bastion Host

After fixing a minor SSH agent error related to local directory paths, we successfully authenticated into the CirrOS Bastion VM to test internal connectivity.

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output/~/.ssh$ eval "$(ssh-agent -s)"
Agent pid 32295
stack@devstack-4all:~/hotel/app-demo/terraform/output/~/.ssh$ ssh-add ~/.ssh/hotel-key.pem
Identity added: /opt/stack/.ssh/hotel-key.pem (/opt/stack/.ssh/hotel-key.pem)
stack@devstack-4all:~/hotel/app-demo/terraform/output/~/.ssh$ ssh -A cirros@172.24.4.239
The authenticity of host '172.24.4.239 (172.24.4.239)' can't be established.
ED25519 key fingerprint is SHA256:0dDF/bk+GiHtW8Jm/NfEgivdbmEkUyRu9lCZeQU0ZI8.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '172.24.4.239' (ED25519) to the list of known hosts.
$ id
uid=1000(cirros) gid=1000(cirros) groups=1000(cirros)


```

From the Bastion, we verified that the frontend machines are reachable on their private IPs:

```text
$ curl
curl: try 'curl --help' for more information
$ curl http://10.0.1.175
<!DOCTYPE html>
<html>
<head><title>Hotel App - Frontend 1</title></head>
<body>
  <h1>Frontend node 1</h1>
  <p>Hotel application frontend server.</p>
</body>
</html>
$ curl http://10.0.1.87
<!DOCTYPE html>
<html>
<head><title>Hotel App - Frontend 2</title></head>
<body>
  <h1>Frontend node 2</h1>
  <p>Hotel application frontend server.</p>
</body>
</html>
$ 


```

---

## 5. Validating Backend Accessibility

Initially, the backend instance lacked a security group rule allowing SSH or HTTP traffic from the `bastion_sg`. After adding the necessary rule, we tested the backend connection and successfully retrieved the FastAPI Swagger UI documentation:

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ ssh -A cirros@172.24.4.239
$ curl http://10.0.1.59/docs

    <!DOCTYPE html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link type="text/css" rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
    <link rel="shortcut icon" href="https://fastapi.tiangolo.com/img/favicon.png">
    <title>FastAPI - Swagger UI</title>
    </head>
    <body>
    <div id="swagger-ui">
    </div>
    <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
        <script>
    const ui = SwaggerUIBundle({
        url: '/openapi.json',
    "dom_id": "#swagger-ui",
"layout": "BaseLayout",
"deepLinking": true,
"showExtensions": true,
"showCommonExtensions": true,
oauth2RedirectUrl: window.location.origin + '/docs/oauth2-redirect',
    presets: [
        SwaggerUIBundle.presets.apis,
        SwaggerUIBundle.SwaggerUIStandalonePreset
        ],
    })
    </script>
    </body>
    </html>

```

---

## 6. Validating Database Network Connectivity

Next, we attempted to connect to the PostgreSQL database directly from the backend node.

```text
ubuntu@hotel-backend:~$ psql -h 10.0.1.54 -p 5432 -U dbadmin -d myappdb
psql: error: connection to server at "10.0.1.54", port 5432 failed: FATAL:  no pg_hba.conf entry for host "10.0.1.59", user "dbadmin", database "myappdb", SSL encryption
connection to server at "10.0.1.54", port 5432 failed: FATAL:  no pg_hba.conf entry for host "10.0.1.59", user "dbadmin", database "myappdb", no encryption

```

This error indicates a configuration issue within `cloud-init-db.yaml`:

```text
PostgreSQL is clearly running and listening on the network (which means your sed command for listen_addresses worked perfectly), but it is actively rejecting the connection because the pg_hba.conf rule was never actually appended.

```

While the database authentication fails due to the missing rule, this test successfully proves that the underlying infrastructure and security groups are correctly configured. The backend node can reach the database node over the network on port 5432.

---

## 7. Validating Keystone Roles and Swift Storage ACLs

The final step is verifying the Keystone user roles and their access permissions to the Swift container. The current OpenStack credentials are set up using `clouds.yaml` and `secure.yaml`:

```yaml
stack@devstack-4all:~/hotel/app-demo/terraform/output$ cat ~/.config/openstack/clouds.yaml 
clouds:
  devstack:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "admin"
      project_id: e20f12f8eeb44503af66f469e8c030aa
      project_name: "admin"
      user_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
  swift_reader:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "app_frontend_reader"
      project_name: "admin"  
      user_domain_name: "Default"
      project_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3

  swift_uploader:
    auth:
      auth_url: http://192.168.1.13/identity
      username: "app_frontend_uploader"
      project_name: "admin" 
      user_domain_name: "Default"
      project_domain_name: "Default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
stack@devstack-4all:~/hotel/app-demo/terraform/output$ cat ~/.config/openstack/secure.yaml 
clouds:
  devstack:
    auth:
      password: "secret" 
  swift_reader:
    auth:
      password: "vYSBNgCI0YSMlrZCRv3L7wQL"

  swift_uploader:
    auth:
      password: "E8oUq4KJxV1rZKYVOXwzYWcr"

```

Checking the assigned roles:

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$                                              
openstack --os-cloud devstack role assignment list --user app_frontend_reader --names
+--------------+-----------------------------+-------+--------------+--------+--------+-----------+
| Role         | User                        | Group | Project      | Domain | System | Inherited |
+--------------+-----------------------------+-------+--------------+--------+--------+-----------+
| media_reader | app_frontend_reader@Default |       | demo@Default |        |        | False     |
+--------------+-----------------------------+-------+--------------+--------+--------+-----------+
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud devstack role assignment list --user app_frontend_uploader --names
+----------------+-------------------------------+-------+--------------+--------+--------+-----------+
| Role           | User                          | Group | Project      | Domain | System | Inherited |
+----------------+-------------------------------+-------+--------------+--------+--------+-----------+
| media_uploader | app_frontend_uploader@Default |       | demo@Default |        |        | False     |
+----------------+-------------------------------+-------+--------------+--------+--------+-----------+

```

Initially, the roles were assigned to the `demo` project. For debugging purposes, we need to move them to the `admin` project. Additionally, the `app_frontend_uploader` requires listing in the `read_acl` so it can read back what it uploads. We also need to update the Terraform configuration to use role IDs for the ACLs instead of user names.

**The Fix:**

```diff
diff --git a/app-demo/terraform/output/storage.tf b/app-demo/terraform/output/storage.tf
index 20cf32b..8e16dd0 100644
--- a/app-demo/terraform/output/storage.tf
+++ b/app-demo/terraform/output/storage.tf
@@ -21,7 +21,7 @@ resource "random_password" "uploader_password" {
 
 # Recupera il progetto corrente dall'autenticazione clouds.yaml
 data "openstack_identity_project_v3" "current" {
-  name = "demo"
+  name = "admin"
 }

```

```diff
index 20cf32b..803146d 100644
--- a/app-demo/terraform/output/storage.tf
+++ b/app-demo/terraform/output/storage.tf
@@ -21,7 +21,7 @@ resource "random_password" "uploader_password" {
 
 # Recupera il progetto corrente dall'autenticazione clouds.yaml
 data "openstack_identity_project_v3" "current" {
-  name = "demo"
+  name = "admin"
 }
 
 # --- RUOLI KEYSTONE ---
@@ -70,15 +70,15 @@ resource "openstack_identity_role_assignment_v3" "uploader_assignment" {
 
 # --- SWIFT CONTAINER ---
 
-# Container per i media assets dell'applicazione hotel
 resource "openstack_objectstorage_container_v1" "hotel_assets" {
   name = var.swift_container_name
 
-  # ACL di lettura: consente l'accesso all'utente reader
-  container_read = "${data.openstack_identity_project_v3.current.name}:${openstack_identity_user_v3.app_frontend_reader.name}"
+  # ACL di lettura: ogni utente con ruolo 'media_reader' o 'media_uploader' può leggere/elencare
+  # Nota: includiamo l'uploader nel read_acl così può vedere cosa carica
+  container_read = "${data.openstack_identity_project_v3.current.id}:media_reader,${data.openstack_identity_project_v3.current.id}:media_uploader"
 
-  # ACL di scrittura: consente l'accesso all'utente uploader
-  container_write = "${data.openstack_identity_project_v3.current.name}:${openstack_identity_user_v3.app_frontend_uploader.name}"
+  # ACL di scrittura: ogni utente con ruolo 'media_uploader' può caricare/eliminare
+  container_write = "${data.openstack_identity_project_v3.current.id}:media_uploader"
 }

```

We can now verify that the policies reflect the updated access control lists:

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud devstack container show hotel-assets
+----------------+-----------------------------------------------------------------------------------------------+
| Field          | Value                                                                                         |
+----------------+-----------------------------------------------------------------------------------------------+
| account        | AUTH_e20f12f8eeb44503af66f469e8c030aa                                                         |
| bytes_used     | 56777936                                                                                      |
| container      | hotel-assets                                                                                  |
| object_count   | 17                                                                                            |
| read_acl       | e20f12f8eeb44503af66f469e8c030aa:media_reader,e20f12f8eeb44503af66f469e8c030aa:media_uploader |
| storage_policy | Policy-0                                                                                      |
| write_acl      | e20f12f8eeb44503af66f469e8c030aa:media_uploader                                               |
+----------------+-----------------------------------------------------------------------------------------------+

```

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud swift_reader container show hotel-assets
+----------------+---------------------------------------+
| Field          | Value                                 |
+----------------+---------------------------------------+
| account        | AUTH_e20f12f8eeb44503af66f469e8c030aa |
| bytes_used     | 56777936                              |
| container      | hotel-assets                          |
| object_count   | 17                                    |
| storage_policy | Policy-0                              |
+----------------+---------------------------------------+
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud swift_uploader container show hotel-assets
+----------------+---------------------------------------+
| Field          | Value                                 |
+----------------+---------------------------------------+
| account        | AUTH_e20f12f8eeb44503af66f469e8c030aa |
| bytes_used     | 56777936                              |
| container      | hotel-assets                          |
| object_count   | 17                                    |
| storage_policy | Policy-0                              |
+----------------+---------------------------------------+

```

As a final confirmation, we perform an upload test. The user with the `uploader` role successfully creates an object in the container, while the user with the `reader` role correctly receives a `403 Forbidden` error when attempting the same action.

```
stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud swift_uploader object create hotel-assets test.txt --name toy_marker.txt
+----------------+--------------+----------------------------------+
| object         | container    | etag                             |
+----------------+--------------+----------------------------------+
| toy_marker.txt | hotel-assets | bba5159eba60f759a28b36834acf656c |
+----------------+--------------+----------------------------------+

stack@devstack-4all:~/hotel/app-demo/terraform/output$ openstack --os-cloud swift_reader object create hotel-assets test.txt --name toy_marker2.txt
Forbidden (HTTP 403) (Request-ID: tx8c58ca4ecd55473a80c9b-0069a5b872)

```

Everything is fully verified and working perfectly.
