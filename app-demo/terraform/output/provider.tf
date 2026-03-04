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
