variable "os_username" {
  description = "OpenStack username for DevStack"
  type        = string
  default     = "admin"
}

variable "os_tenant_name" {
  description = "OpenStack project/tenant name"
  type        = string
  default     = "admin"
}

variable "os_password" {
  description = "OpenStack password"
  type        = string
  default     = "secret"
}

variable "os_auth_url" {
  description = "Keystone authentication URL"
  type        = string
  default     = "http://192.168.1.13/identity/v3"
}

variable "os_region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}
