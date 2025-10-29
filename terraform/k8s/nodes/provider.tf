terraform {
  required_providers {
    # see https://registry.terraform.io/providers/bpg/proxmox
    # see https://github.com/bpg/terraform-provider-proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.86.0"
    }
    # see https://registry.terraform.io/providers/siderolabs/talos
    # see https://github.com/siderolabs/terraform-provider-talos
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
  }
}
