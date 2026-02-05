variable "image_name" {
  type    = string
  default = "ubuntu-22.04"
}

variable "flavor_name" {
  type    = string
  default = "m1.tiny" # Reduced from m1.small to fit in DevStack memory constraints
}

variable "db_password" {
  type    = string
  default = "test"
  sensitive = true
}

variable "ssh_key_name" {
  type    = string
  default = "hotel-key" # We now create this in keypair.tf
}
