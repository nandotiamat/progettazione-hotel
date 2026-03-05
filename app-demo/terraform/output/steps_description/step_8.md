# Step 8: Object Storage (Swift)

## Goal
Create a Swift object storage container for application assets and configure RBAC using Keystone.

## Rationale
- **Swift Container `hotel-assets`**: Creates the storage namespace.
- **Access Control (ACLs)**: Direct assignment of the users (`app_frontend_reader` and `app_frontend_uploader`) limits access strictly to authorized service accounts without making the bucket fully public, adhering to security best practices.
- **Seeding Objects**: By dynamically generating a dummy asset file and uploading it via `openstack_objectstorage_object_v1`, the application has immediate content upon booting, removing manual user intervention.

## Alternatives
- **Public Container**: Instead of enforcing Keystone ACLs, we could have set the bucket policy to public read (`.r:*`). This violates secure default principles.
