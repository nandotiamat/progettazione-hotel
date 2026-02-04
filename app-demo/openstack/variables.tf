variable "image_name" {
  type    = string
  default = "cirros-0.6.3-x86_64-disk" # Available in current DevStack
}

variable "flavor_name" {
  type    = string
  default = "m1.nano" # Reduced from m1.small to fit in DevStack memory constraints
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
