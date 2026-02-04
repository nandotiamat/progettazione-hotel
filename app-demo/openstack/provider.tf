terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  # Assumes OS_ env vars are set in the shell:
  # OS_AUTH_URL, OS_PROJECT_ID/NAME, OS_USERNAME, OS_PASSWORD, OS_REGION_NAME
  # insecure = true # Often needed for DevStack if using self-signed certs
}
