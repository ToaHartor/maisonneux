terraform {
  required_providers {
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.64.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = "2.14.1"
    }
    # see https://registry.terraform.io/providers/siderolabs/talos
    # see https://github.com/siderolabs/terraform-provider-talos
    talos = {
      source  = "siderolabs/talos"
      version = "0.5.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
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

