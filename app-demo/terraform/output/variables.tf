variable "external_network_name" {
  type        = string
  description = "Name of the external (public) network used for router gateway and floating IPs."
  default     = "public"
}

variable "app_name" {
  type        = string
  description = "Prefix used for naming OpenStack resources."
  default     = "hotel-app"
}

variable "network_cidr" {
  type        = string
  description = "Tenant subnet CIDR for the application network."
  default     = "10.50.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.network_cidr))
    error_message = "network_cidr must be a valid IPv4 CIDR (e.g. 10.50.0.0/24)."
  }
}

variable "network_dns_nameservers" {
  type        = list(string)
  description = "DNS nameservers to configure on the tenant subnet."
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR allowed to SSH to instances (set to your workstation/VPN range)."
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.ssh_ingress_cidr))
    error_message = "ssh_ingress_cidr must be a valid IPv4 CIDR (e.g. 203.0.113.10/32)."
  }
}

variable "backend_count" {
  type        = number
  description = "Number of backend instances (autoscaling is emulated via fixed count)."
  default     = 2

  validation {
    condition     = var.backend_count >= 1 && var.backend_count <= 10
    error_message = "backend_count must be between 1 and 10."
  }
}

variable "backend_app_port" {
  type        = number
  description = "Backend application port."
  default     = 8000
}

variable "lb_listen_port" {
  type        = number
  description = "Load balancer listener port."
  default     = 80
}

variable "db_port" {
  type        = number
  description = "Postgres port."
  default     = 5432
}

variable "db_name" {
  type        = string
  description = "Postgres database name."
  default     = "app"
}

variable "db_user" {
  type        = string
  description = "Postgres user name."
  default     = "app"
}

variable "db_password" {
  type        = string
  description = "Postgres user password. If empty, a random password is generated."
  sensitive   = true
  default     = ""
}

variable "db_volume_size_gb" {
  type        = number
  description = "Optional Cinder volume size for DB data. Set to 0 to use root disk only."
  default     = 10

  validation {
    condition     = var.db_volume_size_gb >= 0 && var.db_volume_size_gb <= 200
    error_message = "db_volume_size_gb must be between 0 and 200."
  }
}

variable "env_file_path" {
  type        = string
  description = "Where to write the generated dotenv file (local to the Terraform runner)."
  default     = "../config/devstack.env"
}
