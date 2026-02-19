# 2. Container Swift per i Media (User Uploads)
# Come in AWS, questo rimane privato di default se non impostiamo container_read.
resource "openstack_objectstorage_container_v1" "media_container" {
  name = "my-app-media-assets"
}


# --- POPOLAMENTO STORAGE (SEEDING MEDIA) ---

locals {
  media_files = {
    "prop01/front.png"   = "${path.module}/seed_media/prop01_front.png"
    "prop02/front.png"   = "${path.module}/seed_media/prop02_front.png"
    "prop03/front.png"   = "${path.module}/seed_media/prop03_front.png"
    "prop03/interior.png" = "${path.module}/seed_media/prop03_interior.png"
    "prop03/hall.png"    = "${path.module}/seed_media/prop03_hall.png"
    "prop04/front.png"   = "${path.module}/seed_media/prop04_front.png"
    "prop05/front.png"   = "${path.module}/seed_media/prop05_front.png"
    "prop06/front.png"   = "${path.module}/seed_media/prop06_front.png"
    "prop07/front.png"   = "${path.module}/seed_media/prop07_front.png"
    "prop07/hall.png"    = "${path.module}/seed_media/prop07_hall.png"
    "prop07/interior.png" = "${path.module}/seed_media/prop07_interior.png"
    "prop08/front.png"   = "${path.module}/seed_media/prop08_front.png"
    "prop08/hall.png"    = "${path.module}/seed_media/prop08_hall.png"
    "prop09/front.png"   = "${path.module}/seed_media/prop09_front.png"
    "prop09/pool.png"    = "${path.module}/seed_media/prop09_pool.png"
    "prop10/front.png"   = "${path.module}/seed_media/prop10_front.png"
    "prop10/hall.png"    = "${path.module}/seed_media/prop10_hall.png"
  }
}

# 3. Equivalente di aws_s3_object (Caricamento file nel container media)
resource "openstack_objectstorage_object_v1" "media_seed" {
  for_each = local.media_files

  container_name = openstack_objectstorage_container_v1.media_container.name
  name           = each.key
  source         = each.value

  content_type = lookup(
    {
      "png"  = "image/png",
      "jpg"  = "image/jpeg",
      "jpeg" = "image/jpeg"
    },
    split(".", each.key)[length(split(".", each.key)) - 1],
    "application/octet-stream"
  )
}

# --- OUTPUTS ---

output "swift_media_container_name" {
  description = "Il nome del container Swift per i media"
  value       = openstack_objectstorage_container_v1.media_container.name
}
