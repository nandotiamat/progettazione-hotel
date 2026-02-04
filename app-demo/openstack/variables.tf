variable "image_name" {
  type    = string
  default = "ubuntu-22.04-x86_64" # Adjust based on your DevStack
}

variable "flavor_name" {
  type    = string
  default = "m1.small"
}

variable "db_password" {
  type    = string
  default = "test"
  sensitive = true
}

variable "ssh_key_name" {
  type    = string
  default = "mykey" # Assumes you have an SSH keypair named 'mykey' in OpenStack
}
