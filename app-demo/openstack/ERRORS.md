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
