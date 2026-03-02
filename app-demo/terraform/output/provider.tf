terraform {
  required_version = ">= 1.3.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.49.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "openstack" {
  auth_url = var.openstack_auth_url

  user_name   = var.openstack_user_name
  password    = var.openstack_password
  tenant_name = var.openstack_project_name

  user_domain_name    = var.openstack_user_domain_name
  project_domain_name = var.openstack_project_domain_name

  region = var.openstack_region
}
