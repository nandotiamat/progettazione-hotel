variable "image_name" {
  type    = string
  default = "cirros-0.6.2-x86_64-disk" # Common DevStack default. WARNING: User Data scripts need Ubuntu!
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
