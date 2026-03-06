# --- Object Storage (Swift) ---

resource "openstack_objectstorage_container_v1" "hotel_assets" {
  name = "hotel-assets"

  # Configure ACLs based on Keystone roles created in step 2
  container_read  = "media_reader"
  container_write = "media_uploader"
}

resource "local_file" "seed_image" {
  content  = "dummy image data"
  filename = "${path.module}/dummy-asset.png"
}

resource "openstack_objectstorage_object_v1" "seed_object" {
  name           = "dummy-asset.png"
  container_name = openstack_objectstorage_container_v1.hotel_assets.name
  content        = local_file.seed_image.content
}
