variable "internal_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "external_network_name" {
  type    = string
  default = "public"
}

variable "image_name" {
  type    = string
  default = "ubuntu-22.04"
}

variable "flavor_name" {
  type    = string
  default = "hotel_flavor"
  # default = "m1.small" 
}

variable "ssh_public_key_path" {
  type        = string
  default     = "./keys/hotel-key.pub"
  description = "Percorso della chiave pubblica SSH"

  validation {
    condition     = fileexists(var.ssh_public_key_path)
    error_message = "La chiave pubblica specificata non esiste. Assicurati di aver lanciato lo script setup_keys.sh."
  }
}
