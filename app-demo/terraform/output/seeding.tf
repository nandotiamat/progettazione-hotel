locals {
  seed_media_dir_abs = can(regex("^/", var.seed_media_dir)) ? var.seed_media_dir : "${path.module}/${var.seed_media_dir}"
  seed_media_files = setunion(
    fileset(local.seed_media_dir_abs, "**/*.png"),
    fileset(local.seed_media_dir_abs, "**/*.jpg"),
    fileset(local.seed_media_dir_abs, "**/*.jpeg"),
  )
}

resource "openstack_objectstorage_object_v1" "seed" {
  for_each = local.seed_media_files

  container_name = openstack_objectstorage_container_v1.assets.name
  name           = each.key
  source         = "${local.seed_media_dir_abs}/${each.key}"

  depends_on = [openstack_objectstorage_container_v1.assets]
}
