resource "random_password" "db_password" {
  length  = 24
  special = true
}
