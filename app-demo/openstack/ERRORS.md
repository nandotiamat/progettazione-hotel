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
