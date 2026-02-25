# Step 6: Object Storage (`storage.tf`)

## Goal

Replace AWS S3 buckets with Swift object storage containers: a public-read frontend container and a private media container. Seed media files using `openstack_objectstorage_object_v1` with the same `for_each` pattern as the original AWS design.

## Rationale

Swift is the object storage service available in DevStack. `openstack_objectstorage_container_v1` maps to S3 buckets, while `openstack_objectstorage_object_v1` maps to S3 objects. The `container_read = ".r:*,.rlistings"` ACL replaces the S3 bucket policy with `Principal = "*"`, making the frontend container publicly readable.

The media container has no public ACL, matching the private S3 media bucket. The seed media files use the same `for_each` over a `locals` map pattern, with `source` pointing to the same seed files (adjusted path for the `output/` subdirectory).

S3 bucket website configuration (index/error documents) and S3 bucket policy were skipped because Swift doesn't have native static website hosting in a basic DevStack setup. This is documented as a known gap.

## Alternatives

1. **Using Cinder volumes for storage** — Block storage, not object storage. Rejected because the original design uses S3 (object storage), and Swift is the correct OpenStack equivalent.
2. **Nginx serving static files from a VM** — Would provide full static website hosting (with index.html routing). Rejected for this step to keep the migration 1:1, but noted as a production recommendation.
3. **Skipping the seed files** — Simpler but would lose data parity. Rejected to maintain the full content seeding from the original design.
