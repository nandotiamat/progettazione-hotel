# Recuperiamo l'ID del progetto in cui stiamo lavorando (es. "admin")
data "openstack_identity_project_v3" "current_project" {
  name = "hotel" 
}

