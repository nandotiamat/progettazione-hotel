# Step 3: Storage Configuration

## Goal
Replace AWS S3 buckets with OpenStack Swift (Object Storage) containers.

## Rationale
Since `Swift` is the only storage service active in the DevStack configuration without full Cinder volumes, `openstack_objectstorage_container_v1` is used to represent the S3 bucket. Access control (`container_read`) was used to make it readable in a way analogous to S3's "public-read" ACL.

## Alternatives
*   **Alternative considered:** Deploying MinIO onto a Nova instance for direct S3 compatibility.
*   **Why it was not chosen:** We want to rely natively on OpenStack DevStack services whenever available to keep resource usage minimal and avoid breaking the 6 vCPU constraint. Swift acts functionally equivalent to basic S3 functionality.