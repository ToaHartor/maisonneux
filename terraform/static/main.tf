module "nodes" {
  source            = "./nodes"
  data_disks        = var.data_disks
  proxmox_node_name = var.proxmox_node_name
}

module "lxc" {
  source = "./lxc"
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.69.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_endpoint
  # api_token = var.proxmox_api_token
  username = var.proxmox_root_user
  password = var.proxmox_root_password
  insecure = true
  ssh {
    agent = true
    # username = "root"
    private_key = file(var.proxmox_private_key_path)
  }
}
