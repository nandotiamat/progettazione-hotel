variable "openstack_cloud" {
  description = "The name of the cloud in clouds.yaml to use for authentication"
  type        = string
  default     = "devstack"
}

variable "project_id" {
  description = "The default project ID for the OpenStack environment"
  type        = string
}

variable "external_network_name" {
  description = "The name of the external network in OpenStack"
  type        = string
  default     = "public"
}