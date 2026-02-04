# Terraform Errors Log

This document tracks errors encountered during the migration to OpenStack and their solutions.

## Error Log

### 1. Invalid Resource Type in storage.tf

**Error:**
```
Error: invalid resource type
  on storage.tf line 3: resource "openstack_object_storage_container_v1" "media_container"
  on storage.tf line 14: resource "openstack_object_storage_object_v1" "seed_media"
```

**Cause:**
The resource names for Object Storage in the OpenStack provider were incorrect. The provider uses the service name `objectstorage` (no underscore), not `object_storage`.

**Solution:**
Renamed resources:
*   `openstack_object_storage_container_v1` -> `openstack_objectstorage_container_v1`
*   `openstack_object_storage_object_v1` -> `openstack_objectstorage_object_v1`

### 2. Missing Image and Swift Service

**Error 1:**
```
Error: Unable to find image with name ubuntu-22.04-x86_64
```

**Error 2:**
```
Error: error creating OpenStack object storage client: No suitable endpoint could be found in the service catalog.
```

**Cause:**
1.  **Image:** The DevStack environment does not have an image named `ubuntu-22.04-x86_64`. It likely uses `cirros-0.6.2-x86_64-disk` or has a different naming convention for Ubuntu.
2.  **Swift:** The DevStack installation does not have the Object Storage (Swift) service enabled.

**Solution:**
1.  **Image:** Update `variables.tf` to default to `cirros-0.6.2-x86_64-disk` (to ensure `apply` works) but strongly advise the user to provide a valid Debian/Ubuntu image name for the application to actually run.
2.  **Swift:** Refactor the architecture to remove the dependency on Swift. We will move Media Storage to the Gateway Node (Local File System) and serve it via Nginx.

### 3. Image Version Mismatch (CirrOS 0.6.3)

**Error:**
User reported only `cirros-0.6.3-x86_64-disk` is available, while the default was set to `cirros-0.6.2-x86_64-disk`.

**Solution:**
Updated `variables.tf` to use `cirros-0.6.3-x86_64-disk`.
**Architecture Note:** Since CirrOS cannot run the installation scripts (`user_data` with `apt-get`), the infrastructure will be provisioned successfully, but the application services (Postgres, Nginx, Python) will **not** be installed. This is a known limitation of the current DevStack environment lacking a full Ubuntu image.

### 4. Undeclared Resource in Outputs

**Error:**
```
Reference to undeclared resource
on outputs.tf line 42: SWIFT_CONTAINER_NAME=${openstack_objectstorage_container_v1.media_container.name}
```

**Cause:**
Even though the line was commented out in the `EOF` block, Terraform's interpolation `${...}` is processed **before** the string is evaluated as content. Since we deleted the resource `media_container` (in `storage.tf`), Terraform cannot resolve this reference, even if it's inside a comment within the heredoc string.

**Solution:**
Removed the commented-out line containing the interpolation entirely from `outputs.tf`.

### 5. Missing Authentication Credentials

**Error:**
```
Error: One of 'auth_url' or 'cloud' must be specified
  with provider["registry.terraform.io/terraform-provider-openstack/openstack"],
  on provider.tf line 11, in provider "openstack":
```

**Cause:**
The Terraform provider is not receiving the necessary authentication parameters (`OS_AUTH_URL`, `OS_USERNAME`, etc.). This indicates that the environment variables from the `openrc` file are not currently set in the shell session where `terraform plan` is running.

**Solution:**
The user must source the OpenStack credentials file again.
Command: `source ~/devstack/openrc admin admin` (or appropriate path/user).

### 6. Invalid Key Name

**Error:**
```
Error: Error creating OpenStack server: Bad request with: ... message: "Invalid key_name provided."
```

**Cause:**
The Terraform configuration references an SSH key named `mykey` (in `variables.tf`), but this key does not exist in the OpenStack environment.

**Solution:**
We will create a Terraform resource `openstack_compute_keypair_v2` to create the keypair automatically if it doesn't exist, and update `variables.tf` to depend on this resource (or just hardcode the reference).
Alternatively, the user can create the key manually, but automating it is safer.
We will add `keypair.tf` to create a key named `hotel-key` and update the variable default.

### 7. Instance Build Failure (Status: ERROR)

**Error:**
```
Error: Error waiting for instance (...) to become ready: unexpected state 'ERROR', wanted target 'ACTIVE'. last error: %!s(<nil>)
```
This affected `app_node[0]`, `app_node[1]`, and `auth_node`. `db_node` succeeded.

**Cause Analysis:**
The instances failed to spawn (went to ERROR state instead of ACTIVE). Common causes in DevStack:
1.  **Quota Exceeded:** The flavor `m1.small` (default) typically requests 2GB RAM. Launching 4 VMs (DB, 2 Apps, Auth) = 8GB RAM. If the DevStack VM (running in VirtualBox) has only 4GB or 8GB total, OpenStack kills the spawn due to "No valid host was found" (insufficient RAM/CPU).
2.  **Networking:** Neutron port binding failure (less likely if one succeeded).

**Investigation Steps (for User):**
Check the failure reason on the OpenStack side: `openstack server show <instance_id>`. Look for `fault`.

**Probable Solution (Resource Constraints):**
Change the flavor to something smaller (e.g., `m1.nano` or `m1.tiny`) in `variables.tf`. `m1.tiny` usually takes 512MB RAM, which is much safer for a 4-VM deployment on a single DevStack node.

**Action:**
Update `variables.tf` to default `flavor_name` to `m1.tiny` (or `m1.nano` if available).
