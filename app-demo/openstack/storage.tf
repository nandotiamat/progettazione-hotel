# --- OBJECT STORAGE (Swift) ---

resource "openstack_object_storage_container_v1" "media_container" {
  name = "hotel-media"
  
  # Make it public (read-only)
  container_read = ".r:*" 
}

# --- SEED MEDIA UPLOAD ---
# This requires the machine running Terraform to have access to the OpenStack API
# and the python-swiftclient or similar, or we use the provider's object resource.

resource "openstack_object_storage_object_v1" "seed_media" {
  for_each = fileset("${path.module}/seed_media", "**/*")

  container_name = openstack_object_storage_container_v1.media_container.name
  name           = each.value
  source         = "${path.module}/seed_media/${each.value}"
  
  # Simplistic content type mapping
  content_type = endswith(each.value, ".png") ? "image/png" : "application/octet-stream"
}
