# # following rights described in https://github.com/sergelogvinov/proxmox-csi-plugin?tab=readme-ov-file#proxmox-csi-plugin-user

# resource "proxmox_virtual_environment_role" "csi_driver" {
#   role_id = "csi-driver"

#   privileges = [
#     "VM.Audit",
#     "VM.Config.Disk",
#     "Datastore.Allocate",
#     "Datastore.AllocateSpace",
#     "Datastore.Audit"
#   ]
# }

# resource "proxmox_virtual_environment_user" "kubernetes_csi" {
#   acl {
#     path      = "/"
#     propagate = true
#     role_id   = proxmox_virtual_environment_role.csi_driver.role_id
#   }

#   comment  = "Managed by Terraform"
#   password = random_password.pve_password.result
#   user_id  = "kubernetes-csi@pve"
# }

# resource "proxmox_virtual_environment_user_token" "kubernetes_csi_token" {
#   comment               = "Managed by Terraform"
#   token_name            = "k8s_csi"
#   privileges_separation = false
#   user_id               = proxmox_virtual_environment_user.kubernetes_csi.user_id
# }

# resource "random_password" "pve_password" {
#   length           = 24
#   special          = true
#   override_special = "!#$%&*()-_=+[]{}<>:?"
# }
