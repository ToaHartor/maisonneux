variable "proxmox_api_endpoint" {
  type        = string
  description = "Proxmox cluster API endpoint with https"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token bpg proxmox provider with ID and token"
}

variable "proxmox_root_user" {
  type        = string
  description = "Proxmox cluster API endpoint with https"
}

variable "proxmox_root_password" {
  type        = string
  description = "Proxmox API token bpg proxmox provider with ID and token"
}

variable "proxmox_private_key_path" {
  type        = string
  description = "Private key path to log onto Proxmox via SSH"
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node name"
}

variable "proxmox_cluster_name" {
  type        = string
  description = "Proxmox cluster name"
}

# see https://github.com/siderolabs/talos/releases
# see https://www.talos.dev/v1.7/introduction/support-matrix/
variable "talos_version" {
  type = string
  # renovate: datasource=github-releases depName=siderolabs/talos
  default = "1.9.1"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)+", var.talos_version))
    error_message = "Must be a version number."
  }
}

# see https://github.com/siderolabs/kubelet/pkgs/container/kubelet
# see https://www.talos.dev/v1.7/introduction/support-matrix/
variable "kubernetes_version" {
  type = string
  # renovate: datasource=github-releases depName=siderolabs/kubelet
  default = "1.31.3"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)+", var.kubernetes_version))
    error_message = "Must be a version number."
  }
}

variable "controller_count" {
  type    = number
  default = 1
  validation {
    condition     = var.controller_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "worker_count" {
  type    = number
  default = 1
  validation {
    condition     = var.worker_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "example"
}

variable "cluster_vip" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "192.168.1.79"
}

variable "cluster_endpoint" {
  description = "The k8s api-server (VIP) endpoint"
  type        = string
  default     = "https://192.168.1.79:6443" # k8s api-server endpoint.
}

variable "cluster_node_network_gateway" {
  description = "The IP network gateway of the cluster nodes"
  type        = string
  default     = "192.168.1.254"
}

variable "cluster_node_network" {
  description = "The IP network prefix of the cluster nodes"
  type        = string
  default     = "192.168.1.0/24"
}

variable "cluster_subnet" {
  description = "The IP network subnet mask"
  type        = number
  default     = 24
  validation {
    condition     = var.cluster_subnet >= 0 && var.cluster_subnet <= 32
    error_message = "Must be a valid subnet mask"
  }
}

variable "cluster_pod_cidr" {
  description = "CIDR of IP address of pods inside the cluster"
  type        = string
  default     = "10.244.0.0/16"
}

variable "cluster_node_network_first_controller_hostnum" {
  description = "The hostnum of the first controller host"
  type        = number
  default     = 80
}

variable "cluster_node_network_first_worker_hostnum" {
  description = "The hostnum of the first worker host"
  type        = number
  default     = 90
}

variable "cluster_node_network_load_balancer_first_hostnum" {
  description = "The hostnum of the first load balancer host"
  type        = number
  default     = 130
}

variable "cluster_node_network_load_balancer_last_hostnum" {
  description = "The hostnum of the last load balancer host"
  type        = number
  default     = 230
}

variable "ingress_domain" {
  description = "the DNS domain of the ingress resources"
  type        = string
  default     = "example.test"
}

variable "cluster_prefix" {
  type    = string
  default = "talos"
}

variable "cluster_os_storage" {
  description = "Number of GB the OS disk of each node should have"
  type        = number
  default     = 40
  validation {
    condition     = var.cluster_os_storage >= 1
    error_message = "Must be 1 or more."
  }
}

variable "proxmox_vm_storage" {
  description = "Storage name in Proxmox for PVC usage"
  type        = string
  default     = "data"
}
