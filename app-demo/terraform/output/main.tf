terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.1.0"
    }
  }
}

provider "openstack" {
  user_name   = var.os_username
  tenant_name = var.os_tenant_name
  password    = var.os_password
  auth_url    = var.os_auth_url
  region      = var.os_region
}
