variable "os_cloud" {
  type        = string
  description = "clouds.yaml cloud name (OS_CLOUD)."
  default     = "devstack"
}

variable "jammy_image_source_url" {
  type        = string
  description = "URL reachable by Glance for jammy-server-cloudimg-amd64.img."
  default     = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}

variable "cirros_image_name" {
  type        = string
  description = "Existing Cirros image name in Glance."
  default     = "cirros"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Where to write the generated SSH private key."
  default     = "~/.ssh/hotel-key.pem"
}

variable "external_network_name" {
  type        = string
  description = "Name of the external/public network in DevStack (often 'public')."
  default     = "public"
}

variable "dns_nameservers" {
  type        = list(string)
  description = "DNS servers to hand out via DHCP on the private subnet."
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name."
  default     = "hotel"
}

variable "db_user" {
  type        = string
  description = "PostgreSQL user name."
  default     = "hotel"
}

variable "keystone_default_password_length" {
  type        = number
  description = "Length for generated Keystone user passwords."
  default     = 24
}

variable "keystone_project_name" {
  type        = string
  description = "Keystone project/tenant name to bind roles into."
  default     = "demo"
}

variable "seed_media_dir" {
  type        = string
  description = "Directory with seed media (.png/.jpg/.jpeg) to upload to Swift."
  default     = "seed_media"
}
