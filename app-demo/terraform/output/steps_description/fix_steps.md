# Fix Steps
Here are described the steps required to fix what basic opus4.6 was not capable of doing right.

The first thing that must be fixed is adding the `loadbalancer_provider = "ovn"` line in the load balancer resource. Otherwise, it will create a lb that has as a provider `amphora` which is not available, hence it will be stuck in a `PENDING_CREATE` status. Furthermore if we try to delete that LB via the openstack cli, we'll get an error due to its state being `PENDING_CREATE`.

```diff
 resource "openstack_lb_loadbalancer_v2" "app_lb" {
    name                  = "myapp-load-balancer"
    vip_subnet_id         = openstack_networking_subnet_v2.public_1.id
    admin_state_up        = true
+   loadbalancer_provider = "ovn"
 
   security_group_ids = [openstack_networking_secgroup_v2.lb_sg.id]
 }
```

Fixed that, we need to fix the LB components that are based on HTTP (OVN L4), so we must change how lb listener and health monitor behave. It is important to notice that with OVN as provider not all balancing algorithm are supported (hence why `SOURCE_IP_PORT`). 

```diff
 resource "openstack_lb_listener_v2" "http" {
   name            = "myapp-http-listener"
-  protocol        = "HTTP"
+  protocol        = "TCP"
   protocol_port   = 80
   loadbalancer_id = openstack_lb_loadbalancer_v2.app_lb.id
   admin_state_up  = true
 }

 resource "openstack_lb_pool_v2" "app_pool" {
   name        = "myapp-backend-pool"
-  protocol    = "HTTP"
-  lb_method   = "ROUND_ROBIN"
+  protocol    = "TCP"
+  lb_method   = "SOURCE_IP_PORT"
   listener_id = openstack_lb_listener_v2.http.id
 }
 
 resource "openstack_lb_monitor_v2" "app_monitor" {
   name        = "myapp-health-monitor"
   pool_id     = openstack_lb_pool_v2.app_pool.id
-  type           = "HTTP"
-  http_method    = "GET"
-  url_path       = "/"
-  expected_codes = "200-499"
+  type        = "TCP"
+  delay       = 10
+  timeout     = 5
+  max_retries = 10
 }

```


Then we can move on to the nova compute instances. It uses `cirros` as default image, but opus 4.6 suggested to use `user_data` fields filled with scripts to initially setup the VMs. However, neither `cirros` has the required stuff to download packages, nor the router is setup to allow traffic to and from the internet! 

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

openstack image create "ubuntu-22.04" \
  --file jammy-server-cloudimg-amd64.img \
  --disk-format qcow2 \
  --container-format bare \
  --public
```

```txt
+--------------------------------------+--------------------------+--------+
| ID                                   | Name                     | Status |
+--------------------------------------+--------------------------+--------+
| 9f8a9c1c-6f62-4820-a03a-e04f23e76f69 | amphora-x64-haproxy      | active |
| 49450cdb-ae28-421b-8c4e-0f6124ef973d | cirros-0.6.3-x86_64-disk | active |
| 39fef5c6-6a34-4ddf-9772-37feee4975d7 | ubuntu-22.04             | active |
+--------------------------------------+--------------------------+--------+
```

After we loaded the image, let's edit the variable holding the image name. 

```diff
 variable "image_name" {
   description = "Nome dell'immagine Glance per le istanze compute"
   type        = string
-  default     = "cirros-0.6.3-x86_64-disk"
+  default     = "ubuntu-22.04"
 }
```
We also got the flavor problem (the model did a stupid mistake by giving too much disk space to each vm). Let's create a new flavor that gives less disk space.

```diff
 variable "flavor_name" {
   description = "Nome del flavor per le istanze compute"
   type        = string
-  default     = "m1.small"
+  default     = "hotel_flavor"
 }


However Opus 4.6 thought that the flavor already was created in the environment due to that:

```terraform
data "openstack_compute_flavor_v2" "app_flavor" {
  name = var.flavor_name
}
```
So for now let's just create the flavor via CLI.

```bash
openstack flavor create \
  --ram 2048 \
  --vcpus 1 \
  --disk 10 \
  --public \
  hotel_flavor
```

2 things before we can run `terraform apply` succesfully:
1. fix relative path to `seed_media` folder in `storage.tf`
2. fix path to dotenv file that terraform will generate for us

```diff
resource "openstack_objectstorage_container_v1" "media" {
 locals {
   media_files = {
-    "prop01/front.png"    = "${path.module}/../seed_media/prop01_front.png"
-    "prop02/front.png"    = "${path.module}/../seed_media/prop02_front.png"
-    "prop03/front.png"    = "${path.module}/../seed_media/prop03_front.png"
-    "prop03/interior.png" = "${path.module}/../seed_media/prop03_interior.png"
-    "prop03/hall.png"     = "${path.module}/../seed_media/prop03_hall.png"
-    "prop04/front.png"    = "${path.module}/../seed_media/prop04_front.png"
-    "prop05/front.png"    = "${path.module}/../seed_media/prop05_front.png"
-    "prop06/front.png"    = "${path.module}/../seed_media/prop06_front.png"
-    "prop07/front.png"    = "${path.module}/../seed_media/prop07_front.png"
-    "prop07/hall.png"     = "${path.module}/../seed_media/prop07_hall.png"
-    "prop07/interior.png" = "${path.module}/../seed_media/prop07_interior.png"
-    "prop08/front.png"    = "${path.module}/../seed_media/prop08_front.png"
-    "prop08/hall.png"     = "${path.module}/../seed_media/prop08_hall.png"
-    "prop09/front.png"    = "${path.module}/../seed_media/prop09_front.png"
-    "prop09/pool.png"     = "${path.module}/../seed_media/prop09_pool.png"
-    "prop10/front.png"    = "${path.module}/../seed_media/prop10_front.png"
-    "prop10/hall.png"     = "${path.module}/../seed_media/prop10_hall.png"
+    "prop01/front.png"    = "${path.module}/terraform_content/seed_media/prop01_front.png"
+    "prop02/front.png"    = "${path.module}/terraform_content/seed_media/prop02_front.png"
+    "prop03/front.png"    = "${path.module}/terraform_content/seed_media/prop03_front.png"
+    "prop03/interior.png" = "${path.module}/terraform_content/seed_media/prop03_interior.png"
+    "prop03/hall.png"     = "${path.module}/terraform_content/seed_media/prop03_hall.png"
+    "prop04/front.png"    = "${path.module}/terraform_content/seed_media/prop04_front.png"
+    "prop05/front.png"    = "${path.module}/terraform_content/seed_media/prop05_front.png"
+    "prop06/front.png"    = "${path.module}/terraform_content/seed_media/prop06_front.png"
+    "prop07/front.png"    = "${path.module}/terraform_content/seed_media/prop07_front.png"
+    "prop07/hall.png"     = "${path.module}/terraform_content/seed_media/prop07_hall.png"
+    "prop07/interior.png" = "${path.module}/terraform_content/seed_media/prop07_interior.png"
+    "prop08/front.png"    = "${path.module}/terraform_content/seed_media/prop08_front.png"
+    "prop08/hall.png"     = "${path.module}/terraform_content/seed_media/prop08_hall.png"
+    "prop09/front.png"    = "${path.module}/terraform_content/seed_media/prop09_front.png"
+    "prop09/pool.png"     = "${path.module}/terraform_content/seed_media/prop09_pool.png"
+    "prop10/front.png"    = "${path.module}/terraform_content/seed_media/prop10_front.png"
+    "prop10/hall.png"     = "${path.module}/terraform_content/seed_media/prop10_hall.png"
   }
 }

 resource "local_file" "dotenv" {
-  filename = "/config/openstack.env"
+  filename = "${path.module}/config/openstack.env"
   content  = <<EOF
    ...
```

At this point, we can run `terraform apply` without having creation problems. This is the `terraform output`

```txt
backend_instance_ips = [
  "10.0.3.10",
  "10.0.4.11",
]
db_instance_ip = "10.0.3.100"
db_name = "myappdb"
db_user = "dbadmin"
debug_node_ip = "10.0.4.103"
keystone_auth_url = "http://192.168.1.13/identity"
keystone_backend_role_id = "93685747dcb84d4ea96f22a4dced4dd3"
keystone_owners_role_id = "a85e7f416b174d73a2e4c7cfe94c0996"
keystone_project_id = "1929e1ffc16f46a7837c4cbbef6e3f7a"
lb_vip_address = "10.0.1.161"
network_id = "a67c913f-dfeb-4fb4-94d8-d2d3b2eebf85"
private_subnet_ids = [
  "cd2c2324-bcc8-447f-810d-e13a8cf15456",
  "32ece897-faac-42d1-a76b-7c8960e88012",
]
public_subnet_ids = [
  "475d12c8-8f83-457c-b1fb-f008a3626380",
  "d4836657-1dfa-4d44-bb6a-c057f936b10f",
]
router_id = "f051a51b-c5aa-4451-bb55-ac8f183b58c2"
security_group_compute_id = "8c7a0b2c-6973-491e-89f6-24fdf9124f60"
security_group_db_id = "b3fba887-99bb-4480-b149-9284b42ad8d1"
security_group_lb_id = "9676bb23-a336-4208-9e15-d80e0e1083f3"
swift_frontend_container = "my-app-frontend-container"
swift_frontend_url = "http://192.168.1.13/identity/v1/AUTH_admin/my-app-frontend-container"
swift_media_container = "my-app-media-assets"
swift_media_url = "http://192.168.1.13/identity/v1/AUTH_admin/my-app-media-assets"

```

If we try to run `terraform apply`, the VMs will boot and run the usual cloud-init process, however when it's time to download the packages, we hit the following wall:

TODO N.B forse è bene aggiungere come `depends_on` alle VM le subnet per via di errori di questo tipo

```txt
╷
│ Error: Error creating OpenStack server: Expected HTTP response code [200 202] when accessing [POST http://192.168.1.13/compute/v2.1/servers], but got 400 instead: {"badRequest": {"code": 400, "message": "Network 5e69d5f1-ce2e-4f18-836e-b75e2d0b8a0c requires a subnet in order to boot instances on."}}
│ 
│   with openstack_compute_instance_v2.debug_node,
│   on compute.tf line 102, in resource "openstack_compute_instance_v2" "debug_node":
│  102: resource "openstack_compute_instance_v2" "debug_node" {
│ 
╵
```

```text
[  355.343987] cloud-init[1189]: Cloud-init v. 25.3-0ubuntu1~22.04.1 running 'modules:final' at Sat, 28 Feb 2026 09:27:19 +0000. Up 354.69 seconds.
         Starting [0;1;39mUpdate APT News[0m...
         Starting [0;1;39mUpdate the local ESM caches[0m...
[[0;32m  OK  [0m] Finished [0;1;39mUpdate APT News[0m.
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  383.319111] cloud-init[1189]: Ign:1 http://security.ubuntu.com/ubuntu jammy-security InRelease
[  383.323240] cloud-init[1189]: Ign:2 http://archive.ubuntu.com/ubuntu jammy InRelease
[[0;32m  OK  [0m] Finished [0;1;39mUpdate the local ESM caches[0m.
[  410.177703] cloud-init[1189]: Ign:1 http://security.ubuntu.com/ubuntu jammy-security InRelease
[  410.187659] cloud-init[1189]: Ign:3 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  431.729648] cloud-init[1189]: Ign:4 http://archive.ubuntu.com/ubuntu jammy-backports InRelease
[  436.718839] cloud-init[1189]: Ign:1 http://security.ubuntu.com/ubuntu jammy-security InRelease
[  458.259305] cloud-init[1189]: Ign:2 http://archive.ubuntu.com/ubuntu jammy InRelease
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  468.282084] cloud-init[1189]: Err:1 http://security.ubuntu.com/ubuntu jammy-security InRelease
[  468.287532] cloud-init[1189]:   Temporary failure resolving 'security.ubuntu.com'
[  483.091732] cloud-init[1189]: Ign:3 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
[  508.134284] cloud-init[1189]: Ign:4 http://archive.ubuntu.com/ubuntu jammy-backports InRelease
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  532.717171] cloud-init[1189]: Ign:2 http://archive.ubuntu.com/ubuntu jammy InRelease
         Starting [0;1;39mTime & Date Service[0m...
[  557.304269] cloud-init[1189]: Ign:3 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  581.869150] cloud-init[1189]: Ign:4 http://archive.ubuntu.com/ubuntu jammy-backports InRelease
         Starting [0;1;39mTime & Date Service[0m...
[  606.463051] cloud-init[1189]: Err:2 http://archive.ubuntu.com/ubuntu jammy InRelease
[  606.470663] cloud-init[1189]:   Temporary failure resolving 'archive.ubuntu.com'
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  631.050530] cloud-init[1189]: Err:3 http://archive.ubuntu.com/ubuntu jammy-updates InRelease
[  631.053431] cloud-init[1189]:   Temporary failure resolving 'archive.ubuntu.com'
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  656.266803] cloud-init[1189]: Err:4 http://archive.ubuntu.com/ubuntu jammy-backports InRelease
[  656.271085] cloud-init[1189]:   Temporary failure resolving 'archive.ubuntu.com'
[  663.949122] cloud-init[1189]: Reading package lists...
[  664.093720] cloud-init[1189]: W: Failed to fetch http://archive.ubuntu.com/ubuntu/dists/jammy/InRelease  Temporary failure resolving 'archive.ubuntu.com'
[  664.106677] cloud-init[1189]: W: Failed to fetch http://archive.ubuntu.com/ubuntu/dists/jammy-updates/InRelease  Temporary failure resolving 'archive.ubuntu.com'
[  664.108038] cloud-init[1189]: W: Failed to fetch http://archive.ubuntu.com/ubuntu/dists/jammy-backports/InRelease  Temporary failure resolving 'archive.ubuntu.com'
[  664.109875] cloud-init[1189]: W: Failed to fetch http://security.ubuntu.com/ubuntu/dists/jammy-security/InRelease  Temporary failure resolving 'security.ubuntu.com'
[  664.118919] cloud-init[1189]: W: Some index files failed to download. They have been ignored, or old ones used instead.
[  664.931573] cloud-init[1189]: Reading package lists...
[  665.503024] cloud-init[1189]: Building dependency tree...
[  665.514409] cloud-init[1189]: Reading state information...
[  665.982919] cloud-init[1189]: The following additional packages will be installed:
[  665.987327] cloud-init[1189]:   libcommon-sense-perl libjson-perl libjson-xs-perl libllvm14 libpq5
[  665.995784] cloud-init[1189]:   libsensors-config libsensors5 libtypes-serialiser-perl postgresql-14
[  666.003070] cloud-init[1189]:   postgresql-client-14 postgresql-client-common postgresql-common ssl-cert
[  666.011492] cloud-init[1189]:   sysstat
[  666.013629] cloud-init[1189]: Suggested packages:
[  666.017075] cloud-init[1189]:   lm-sensors postgresql-doc postgresql-doc-14 isag
[  666.310994] cloud-init[1189]: The following NEW packages will be installed:
[  666.315636] cloud-init[1189]:   libcommon-sense-perl libjson-perl libjson-xs-perl libllvm14 libpq5
[  666.319955] cloud-init[1189]:   libsensors-config libsensors5 libtypes-serialiser-perl postgresql
[  666.326593] cloud-init[1189]:   postgresql-14 postgresql-client-14 postgresql-client-common
[  666.337612] cloud-init[1189]:   postgresql-common postgresql-contrib ssl-cert sysstat
[  691.213879] cloud-init[1189]: 0 upgraded, 16 newly installed, 0 to remove and 0 not upgraded.
[  691.216459] cloud-init[1189]: Need to get 42.5 MB of archives.
[  691.218583] cloud-init[1189]: After this operation, 162 MB of additional disk space will be used.
[  691.220067] cloud-init[1189]: Ign:1 http://archive.ubuntu.com/ubuntu jammy/main amd64 libcommon-sense-perl amd64 3.75-2build1
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  718.013922] cloud-init[1189]: Ign:2 http://archive.ubuntu.com/ubuntu jammy/main amd64 libjson-perl all 4.04000-1
[  744.023668] cloud-init[1189]: Ign:3 http://archive.ubuntu.com/ubuntu jammy/main amd64 libtypes-serialiser-perl all 1.01-1
         Starting [0;1;39mTime & Date Service[0m...
[[0;32m  OK  [0m] Started [0;1;39mTime & Date Service[0m.
[  769.677914] cloud-init[1189]: Ign:4 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 libjson-xs-perl amd64 4.040-0ubuntu0.22.04.1
[  794.254387] cloud-init[1189]: Ign:5 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 libllvm14 amd64 1:14.0.0-1ubuntu1.1
[  818.845914] cloud-init[1189]: Ign:6 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 libpq5 amd64 14.20-0ubuntu0.22.04.1
[  843.421618] cloud-init[1189]: Ign:7 http://archive.ubuntu.com/ubuntu jammy/main amd64 libsensors-config all 1:3.6.0-7ubuntu1
[  867.989050] cloud-init[1189]: Ign:8 http://archive.ubuntu.com/ubuntu jammy/main amd64 libsensors5 amd64 1:3.6.0-7ubuntu1
[  892.557886] cloud-init[1189]: Ign:9 http://archive.ubuntu.com/ubuntu jammy/main amd64 postgresql-client-common all 238
         Starting [0;1;39mCleanup of Temporary Directories[0m...
[[0;32m  OK  [0m] Finished [0;1;39mCleanup of Temporary Directories[0m.
[  917.144165] cloud-init[1189]: Ign:10 http://archive.ubuntu.com/ubuntu jammy-updates/main amd64 postgresql-client-14 amd64 14.20-
``` 

At this point, we can also discuss what's the problem with how opus handled the network (TODO: talk about SNAT, DNAT, floating ips, how the public network created acts as if they were private..., creating an interface that connect the subnet to the router allows to get data from the internet (SNAT) but not to be reachable from outside, for that you need a floating ip.)
Next, we'll try to allow the traffic to the internet, so that the machines can download the packages they need.


We need to connect the private subnet to the router that has as `external_network_id` the default `public` network created by devstack.

Created the interface, we expect the Ign error to be gone.
```diff
+resource "openstack_networking_router_interface_v2" "private_1" {
+  router_id = openstack_networking_router_v2.main.id
+  subnet_id = openstack_networking_subnet_v2.private_1.id
+}
```
RIscontrando il problema che non trova il datasource(datasourcenone, non partono gli user_data)

aggiungere un depends on alla subnet RISOLVE questo problema. 


```text
[  252.688175] cloud-init[1219]: Cloud-init v. 25.3-0ubuntu1~22.04.1 running 'modules:final' at Sat, 28 Feb 2026 10:26:29 +0000. Up 251.67 seconds.
         Starting [0;1;39mUpdate APT News[0m...
         Starting [0;1;39mUpdate the local ESM caches[0m...
[  257.841906] cloud-init[1219]: Get:1 http://security.ubuntu.com/ubuntu jammy-security InRelease [129 kB]
[  259.002014] cloud-init[1219]: Hit:2 http://nova.clouds.archive.ubuntu.com/ubuntu jammy InRelease
[  259.023555] cloud-init[1219]: Get:3 http://nova.clouds.archive.ubuntu.com/ubuntu jammy-updates InRelease [128 kB]
[  259.191715] cloud-init[1219]: Get:4 http://nova.clouds.archive.ubuntu.com/ubuntu jammy-backports InRelease [127 kB]
[[0;32m  OK  [0m] Finished [0;1;39mUpdate APT News[0m.
[  266.246831] cloud-init[1219]: Get:5 http://nova.clouds.archive.ubuntu.com/ubuntu jammy/universe amd64 Packages [14.1 MB]
[  274.950515] cloud-init[1219]: Get:6 http://nova.clouds.archive.ubuntu.com/ubuntu jammy/universe Translation-en [5652 kB]
[  278.582063] cloud-init[1219]: Get:7 http://nova.clouds.archive.ubuntu.com/ubuntu jammy/universe amd64 c-n-f Metadata [286 kB]
[  278.870606] cloud-init[1219]: Get:8 http://nova.clouds.archive.ubuntu.com/ubuntu jammy/multiverse amd64 Packages [217 kB]
```

Stiamo raggiungendo le repo di ubuntu jammy e, con successo ,stiamo scaricando i pacchetti.

Ok, now we need to generate a ssh keypair in order to access into the VMs.
Looking at the `compute.tf` we can see that opus 4.6 created a "debug" VM, however it has the following problems:
1. It is NOT attached to a subnet, but to the network itself: the IP it might get assigned might be ambiguous (which subnet?)
2. It doesn't have a dedicated security group

I don't understand what's the purpose for that debug VM
What i'd do there is to have a Bastion VM that i can SSH into (via a floating IP), and then, by having a proper security group, SSH into the VM in the private subnet so that i can debug them, and without exposing them via a floating IP!

In order to do that we need:
1. SSH Keypair and notice the debug node about it
2. Attach the debug node to the right subnet
3. Create a dedicated security group

Let's do that.

Let's create a `keys.tf`

```diff
+   resource "tls_private_key" "ssh_key" {
+     algorithm = "ED25519"
+   }
+
+   resource "local_sensitive_file" "private_key" {
+     content         = tls_private_key.ssh_key.private_key_openssh
+     filename        = pathexpand("~/.ssh/hotel-key") 
+     file_permission = "0600"
+   }
+
+   resource "local_file" "public_key" {
+     content         = tls_private_key.ssh_key.public_key_openssh
+     filename        = "${path.module}/keys/hotel-key.pub"
+     file_permission = "0644"
+   }
+
+   resource "openstack_compute_keypair_v2" "hotel_keypair" {
+     name       = "hotel-keypair"
+     public_key = tls_private_key.ssh_key.public_key_openssh
+   }
```

Obviously that adds a new provider.

Let's add the `key_pair` field to each compute node. For the debug node, let's give it a PROPER ip in the private_1 subnet.


```diff
resource "openstack_compute_instance_v2" "debug_node" {
   image_id        = data.openstack_images_image_v2.app_image.id
   flavor_id       = data.openstack_compute_flavor_v2.app_flavor.id
   security_groups = [openstack_networking_secgroup_v2.compute_sg.name]
+  key_pair        = openstack_compute_keypair_v2.hotel_keypair.name
 
   network {
-    uuid = openstack_networking_network_v2.main.id
+    uuid        = openstack_networking_network_v2.main.id
+    fixed_ip_v4 = cidrhost(openstack_networking_subnet_v2.private_1.cidr, 99)
   }
```

After that, we need to:

create the security group and an ssh ingress rule for the bastion host, and of course a floating ip for it.

```diff
+   resource "openstack_networking_floatingip_v2" "bastion_fip" {
+     pool = data.openstack_networking_network_v2.external.name
+   }
+   
+   data "openstack_networking_port_v2" "bastion_port" {
+     device_id = openstack_compute_instance_v2.debug_node.id
+   }
+   
+   resource "openstack_networking_floatingip_associate_v2" "frontend_fip_assoc" {
+     floating_ip = openstack_networking_floatingip_v2.bastion_fip.address
+     port_id     = data.openstack_networking_port_v2.bastion_port.id
+   }
``` 

This is for the Floating IP: we create a floating IP resource attached to the public network, then we attach its address to the port id of the bastion

Now we can create the new security group, edit the ssh ingress rule of the backend vms and add the ssh rule ingress to the bastion sg.


```diff
+resource "openstack_networking_secgroup_v2" "bastion_sg" {
+  name        = "bastion-security-group"
+  description = "Permette l'accesso SSH dall'esterno al Bastion Host"
+}
+
+# Ingress SSH (porta 22) da Internet
+resource "openstack_networking_secgroup_rule_v2" "bastion_ingress_ssh" {
+  direction         = "ingress"
+  ethertype         = "IPv4"
+  protocol          = "tcp"
+  port_range_min    = 22
+  port_range_max    = 22
+  remote_ip_prefix  = "0.0.0.0/0"
+  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
+}
```

Then we can also add the `remote_group_id` to the `compute_ingress_ssh` rule:

```diff
resource "openstack_networking_secgroup_rule_v2" "compute_ingress_ssh" {
   protocol          = "tcp"
   port_range_min    = 22
   port_range_max    = 22
-  remote_ip_prefix  = "10.0.0.0/16"
+  remote_group_id   = openstack_networking_secgroup_v2.bastion_sg.id
   security_group_id = openstack_networking_secgroup_v2.compute_sg.id
 }
```

```diff
compute.sg, debug/bastion node
-  security_groups = [openstack_networking_secgroup_v2.compute_sg.name]
+  security_groups = [openstack_networking_secgroup_v2.bastion_sg.name]
```

Only now, we can SSH into the Bastion.

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ ssh -i ~/.ssh/hotel-key ubuntu@172.24.4.43
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-171-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Feb 28 11:49:55 UTC 2026

  System load:  0.16              Processes:             89
  Usage of /:   16.8% of 9.51GB   Users logged in:       0
  Memory usage: 10%               IPv4 address for ens3: 10.0.3.99
  Swap usage:   0%


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.4 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Sat Feb 28 11:44:10 2026 from 172.24.4.1
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.
```

Now we need to do ssh agent forwarding in order to pass the key to the bastion. We just need to add an -A flag.

Of course don't  forget to add the `key_pair` field to each compute node.

```text
stack@devstack-4all:~/hotel/app-demo/terraform/output$ eval "$(ssh-agent -s)" 
Agent pid 78253
stack@devstack-4all:~/hotel/app-demo/terraform/output$ ssh-add ~/.ssh/hotel-key
Identity added: /opt/stack/.ssh/hotel-key (/opt/stack/.ssh/hotel-key)
stack@devstack-4all:~/hotel/app-demo/terraform/output$ ssh -A ubuntu@172.24.4.43
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-171-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Sat Feb 28 15:30:35 UTC 2026

  System load:  0.24              Processes:             90
  Usage of /:   16.8% of 9.51GB   Users logged in:       0
  Memory usage: 10%               IPv4 address for ens3: 10.0.3.99
  Swap usage:   0%

 * Strictly confined Kubernetes makes edge and IoT secure. Learn how MicroK8s
   just raised the bar for easy, resilient and secure K8s cluster deployment.

   https://ubuntu.com/engage/secure-kubernetes-at-the-edge

Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.4 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Sat Feb 28 15:28:37 2026 from 172.24.4.1
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@myapp-debug-node:~$ ssh ubuntu@10.0.3.10
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.15.0-171-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information disabled due to load higher than 1.0


Expanded Security Maintenance for Applications is not enabled.

0 updates can be applied immediately.

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

New release '24.04.4 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Sat Feb 28 15:29:56 2026 from 10.0.3.99
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

ubuntu@myapp-backend-1:~$ 

```
We are in.
Now: one of the two backend is in private_2, however since we have only 1 AZ (devstack), we dont bother to create more than 1 az (however, logically, we could, in devstack).

To test the VMs serving the frontend, we can try to directly debug the LB, however it doesn't have a floating ip, let's create one.

```diff
+   resource "openstack_networking_floatingip_v2" "lb_fip" {
+     pool = data.openstack_networking_network_v2.external.name
+   }
+   
+   resource "openstack_networking_floatingip_associate_v2" "lb_fip_assoc" {
+     floating_ip = openstack_networking_floatingip_v2.lb_fip.address
+     port_id     = openstack_lb_loadbalancer_v2.app_lb.vip_port_id
+   }
```

```diff
resource "openstack_lb_member_v2" "backend" {
   count         = 2
   pool_id       = openstack_lb_pool_v2.app_pool.id
   address       = openstack_compute_instance_v2.backend[count.index].access_ip_v4
-  protocol_port = 80
+  protocol_port = 8000
   subnet_id     = count.index % 2 == 0 ? openstack_networking_subnet_v2.private_1.id : openstack_networking_subnet_v2.private_2.id
 }
```

One funny thing is that the router has no interface for the private network 2, which means that the loadbalancer is able to send packets to the node in `private_1` network, but not to the `private_2` node, since they are in 2 different subnetwork.

We need to add that network interface, otherwise the load balancer wont be able to send packets to that node.

```diff
+   resource "openstack_networking_router_interface_v2" "private_2" {
+     router_id = openstack_networking_router_v2.main.id
+     subnet_id = openstack_networking_subnet_v2.private_2.id
+   }
```

Well, now it works.

```diff
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.128
Backend instance 2
stack@devstack-4all:~/hotel/app-demo/terraform/output$ curl http://172.24.4.128
Backend instance 1
```

Next, we'll try to debug if the machines can talk to each other, so that we can see if the security group and rules are properly working. 