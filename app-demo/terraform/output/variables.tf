/* ------------------------------------------------------------------------
   Variabili centralizzate per l'infrastruttura OpenStack (DevStack).
   Ogni variabile ha description, type e default per consentire
   l'applicazione automatica senza file .tfvars.
   ------------------------------------------------------------------------ */

# --- RETE ---

variable "external_network_name" {
  description = "Nome della rete esterna DevStack"
  type        = string
  default     = "public"
}

variable "dns_nameservers" {
  description = "Server DNS per la subnet privata"
  type        = list(string)
  default     = ["8.8.8.8"]
}

variable "private_network_cidr" {
  description = "CIDR della subnet privata"
  type        = string
  default     = "10.0.1.0/24"
}

# --- DATABASE ---

variable "db_user" {
  description = "Username PostgreSQL"
  type        = string
  default     = "dbadmin"
}

variable "db_name" {
  description = "Nome del database PostgreSQL"
  type        = string
  default     = "myappdb"
}

variable "db_password" {
  description = "Password PostgreSQL (solo per sviluppo locale)"
  type        = string
  default     = "test"
  sensitive   = true
}

# --- IMMAGINE ---

variable "image_url" {
  description = "URL dell'immagine cloud Ubuntu Jammy per Glance"
  type        = string
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

# --- SSH ---

variable "keypair_private_key_path" {
  description = "Percorso di salvataggio della chiave privata SSH"
  type        = string
  default     = "~/.ssh/hotel-key.pem"
}

# --- SWIFT ---

variable "swift_container_name" {
  description = "Nome del container Swift per i media assets"
  type        = string
  default     = "hotel-assets"
}

# --- FILE .ENV ---

variable "env_file_path" {
  description = "Percorso del file .env generato da Terraform"
  type        = string
  default     = "./openstack.env"
}

# --- CLOUD ---

variable "cloud" {
  description = "Nome del cloud nel file clouds.yaml"
  type        = string
  default     = "devstack"
}
