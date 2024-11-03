locals {
  proxmox_csi_cluster = {
    clusters = [
      {
        url          = "${var.proxmox_api_endpoint}/api2/json"
        insecure     = true
        token_id     = split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)[0]
        token_secret = split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)[1]
        region       = "datacenter"
      }
    ]
  }
}
