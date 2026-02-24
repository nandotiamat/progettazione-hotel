/* ------------------------------------------------------------------------
   Variabili di input per l'infrastruttura OpenStack (DevStack).
   Tutte le variabili hanno valori di default adatti a un ambiente DevStack
   locale con branch stable/2025.1.
   ------------------------------------------------------------------------ */

# --- AUTENTICAZIONE OPENSTACK ---

variable "os_auth_url" {
  description = "URL di autenticazione Keystone (identity endpoint)"
  type        = string
  default     = "http://192.168.1.13/identity"
}

variable "os_user_name" {
  description = "Nome utente per autenticazione DevStack"
  type        = string
  default     = "admin"
}

variable "os_password" {
  description = "Password per autenticazione DevStack"
  type        = string
  default     = "secret"
}

variable "os_tenant_name" {
  description = "Nome del progetto (tenant) OpenStack"
  type        = string
  default     = "admin"
}

variable "os_region" {
  description = "Regione OpenStack (default DevStack)"
  type        = string
  default     = "RegionOne"
}

# --- COMPUTE ---

variable "image_name" {
  description = "Nome dell'immagine Glance per le istanze di compute"
  type        = string
  default     = "ubuntu-22.04"
}

variable "flavor_name" {
  description = "Flavor delle istanze di compute (backend)"
  type        = string
  default     = "m1.small"
}

variable "db_flavor_name" {
  description = "Flavor dell'istanza database PostgreSQL"
  type        = string
  default     = "m1.small"
}

variable "debug_flavor_name" {
  description = "Flavor dell'istanza di debug"
  type        = string
  default     = "m1.tiny"
}

# --- DATABASE ---

variable "db_password" {
  description = "Password del database PostgreSQL"
  type        = string
  default     = "test"
}

variable "db_name" {
  description = "Nome del database PostgreSQL"
  type        = string
  default     = "hotel_db"
}

variable "db_user" {
  description = "Utente del database PostgreSQL"
  type        = string
  default     = "hotel_user"
}

# --- RETE ---

variable "external_network_name" {
  description = "Nome della rete esterna DevStack (per il router)"
  type        = string
  default     = "public"
}

variable "dns_nameservers" {
  description = "Server DNS per le subnet"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}

# --- APPLICAZIONE ---

variable "app_port" {
  description = "Porta su cui il backend dell'applicazione ascolta"
  type        = string
  default     = "8000"
}

variable "instance_count" {
  description = "Numero di istanze di compute backend (simula la desired capacity dell'ASG)"
  type        = number
  default     = 2
}
