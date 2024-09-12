#! Some operations require the Root user to be used to modify some rules (such as PCI passthrough iirc), so the following method with a token may not work

# Requires to create an API token for Terraform to log in

# # Create the user
# sudo pveum user add terraform@pve
# # Create a role for the user above
# sudo pveum role add Terraform -privs "Datastore.Allocate Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify SDN.Use VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt User.Modify"
# # Assign the terraform user to the above role
# sudo pveum aclmod / -user terraform@pve -role Terraform
# # Create the token
# sudo pveum user token add terraform@pve provider --privsep=0

# Internal modules to deploy instances
# Use either the static environment (static VM/containers) or the K8S environment
module "nodes" {
  source     = "./static/nodes"
  count      = (terraform.workspace == "static") ? 1 : 0
  data_disks = var.data_disks
}

module "lxc" {
  source = "./static/lxc"
  count  = (terraform.workspace == "static") ? 1 : 0
}

module "k8scluster" {
  source = "./k8s"
  count  = (terraform.workspace == "k8s") ? 1 : 0
  # Variables
  controller_count                                 = var.controller_count
  worker_count                                     = var.worker_count
  talos_version                                    = var.talos_version
  kubernetes_version                               = var.kubernetes_version
  cluster_name                                     = var.cluster_name
  cluster_vip                                      = var.cluster_vip
  cluster_endpoint                                 = var.cluster_endpoint
  cluster_node_network                             = var.cluster_node_network
  cluster_node_network_gateway                     = var.cluster_node_network_gateway
  cluster_subnet                                   = var.cluster_subnet
  cluster_pod_cidr                                 = var.cluster_pod_cidr
  cluster_node_network_first_controller_hostnum    = var.cluster_node_network_first_controller_hostnum
  cluster_node_network_controller_mac_addr_prefix  = var.cluster_node_network_controller_mac_addr_prefix
  cluster_node_network_first_worker_hostnum        = var.cluster_node_network_first_worker_hostnum
  cluster_node_network_worker_mac_addr_prefix      = var.cluster_node_network_worker_mac_addr_prefix
  cluster_node_network_load_balancer_first_hostnum = var.cluster_node_network_load_balancer_first_hostnum
  cluster_node_network_load_balancer_last_hostnum  = var.cluster_node_network_load_balancer_last_hostnum
  ingress_domain                                   = var.ingress_domain
  cluster_prefix                                   = var.cluster_prefix
  cluster_os_storage                               = var.cluster_os_storage
  proxmox_api_endpoint                             = var.proxmox_api_endpoint
  proxmox_vm_storage                               = var.proxmox_vm_storage
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.64.0"
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
