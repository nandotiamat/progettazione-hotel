variable "internal_subnet_cidr" {
  type = string
  default = "10.20.0.0/24"
}

variable "external_network_name" {
  type = string
  default = "public" 
}

variable "image_name" {
  type    = string
  default = "ubuntu-22.04"
}

variable "flavor_name" {
  type    = string
  default = "m1.small" 
}
