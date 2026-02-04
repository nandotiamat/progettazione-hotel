# Terraform Error Resolution Log

This document details the specific errors encountered during the migration from AWS/LocalStack to OpenStack (DevStack) and how each was resolved.

## Summary of Issues

During the `terraform plan` and `terraform apply` phases, we encountered 7 distinct issues ranging from syntax errors to resource exhaustion.

## Detailed Resolution Steps

### 1. Invalid Terraform Resource Types
**Issue:** `storage.tf` used `openstack_object_storage_...` instead of the correct provider syntax.
**Resolution:** Corrected the resource names to `openstack_objectstorage_container_v1` and `openstack_objectstorage_object_v1`.

### 2. Missing Swift (Object Storage) Service
**Issue:** The DevStack environment did not have the Object Storage service (Swift) enabled, causing API errors.
**Resolution:** 
*   Removed `storage.tf`.
*   Refactored the architecture to use **Local Storage** on the Gateway node.
*   Updated `nginx_setup.sh.tpl` to serve media files from `/var/www/html/media`.

### 3. Missing Ubuntu Image
**Issue:** The configuration requested `ubuntu-22.04-x86_64`, which was not present in DevStack.
**Resolution:** Updated `variables.tf` to use `cirros-0.6.2-x86_64-disk` (and later `0.6.3`) as a fallback.
*   *Note:* Using CirrOS means the application provisioning scripts (`user_data`) will not execute, as CirrOS lacks `apt-get` and Python. This validates the infrastructure but not the application deployment.

### 4. Undeclared Resource in Outputs
**Issue:** `outputs.tf` contained a reference to the deleted Swift container resource inside a heredoc string.
**Resolution:** Removed the interpolation line entirely from the `local_file` resource in `outputs.tf`.

### 5. Missing Authentication Credentials
**Issue:** Terraform failed with `One of 'auth_url' or 'cloud' must be specified`.
**Resolution:** The user sourced the OpenStack credentials file (`source ~/devstack/openrc admin admin`) to inject the required `OS_*` environment variables.

### 6. Invalid Key Name
**Issue:** The configuration referenced a non-existent SSH key `mykey`.
**Resolution:** 
*   Created a new file `keypair.tf` with a resource `openstack_compute_keypair_v2 "hotel_key"`.
*   Updated `variables.tf` to use this managed keypair (`hotel-key`) instead of expecting an external one.

### 7. Resource Exhaustion (Instance Build Failure)
**Issue:** Instances stuck in `ERROR` state. The default flavor `m1.small` (2GB RAM) caused the 4-node cluster to exceed the DevStack node's available memory.
**Resolution:** Downgraded the default flavor in `variables.tf` to `m1.nano` (64MB RAM). This allowed all 4 instances (DB, Auth, App x2) to launch successfully within the constrained environment.
