# --- Outputs & Environment Secrets Management ---

resource "local_sensitive_file" "env_file" {
  filename        = "${path.module}/.env"
  content         = <<-EOF
    # Application Environment Configurations
    
    # Keystone Credentials
    SWIFT_USERNAME_READER=${openstack_identity_user_v3.app_frontend_reader.name}
    SWIFT_PASSWORD_READER=${random_password.reader_password.result}
    
    SWIFT_USERNAME_UPLOADER=${openstack_identity_user_v3.app_frontend_uploader.name}
    SWIFT_PASSWORD_UPLOADER=${random_password.uploader_password.result}
    
    # Swift Target
    SWIFT_CONTAINER=${openstack_objectstorage_container_v1.hotel_assets.name}
    
    # Database Configurations
    DB_HOST=${openstack_compute_instance_v2.database.network.0.fixed_ip_v4}
    DB_PORT=5432
    DB_USER=hotel_user
    DB_PASS=hotel_password
    DB_NAME=hotel_db
    
    # Endpoints
    LB_PUBLIC_IP=${openstack_networking_floatingip_v2.lb_fip.address}
    BASTION_PUBLIC_IP=${openstack_networking_floatingip_v2.bastion_fip.address}
  EOF
  file_permission = "0600"
}
