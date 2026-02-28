/* ------------------------------------------------------------------------
   Variabili di input centralizzate.
   Tutti i valori hanno default compatibili con DevStack stable/2025.1.
   ------------------------------------------------------------------------ */

# --- OPENSTACK AUTH ---

variable "os_auth_url" {
  description = "URL di autenticazione Keystone"
  type        = string
  default     = "http://192.168.1.13/identity"
}

variable "os_user_name" {
  description = "Nome utente OpenStack (DevStack)"
  type        = string
  default     = "admin"
}

variable "os_password" {
  description = "Password utente OpenStack (DevStack)"
  type        = string
  default     = "secret"
  sensitive   = true
}

variable "os_tenant_name" {
  description = "Nome del progetto/tenant OpenStack"
  type        = string
  default     = "admin"
}

variable "os_region" {
  description = "Regione OpenStack"
  type        = string
  default     = "RegionOne"
}

# --- DATABASE ---

variable "db_password" {
  description = "Password del database PostgreSQL"
  type        = string
  default     = "test"
  sensitive   = true
}

# --- COMPUTE ---

variable "image_name" {
  description = "Nome dell'immagine Glance per le istanze compute"
  type        = string
  default     = "ubuntu-22.04"
}

variable "flavor_name" {
  description = "Nome del flavor per le istanze compute"
  type        = string
  default     = "hotel_flavor"
}
