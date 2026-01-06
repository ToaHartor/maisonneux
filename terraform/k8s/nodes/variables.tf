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

variable "proxmox_cluster_name" {
  type        = string
  description = "Proxmox cluster name"
}

# see https://github.com/siderolabs/talos/releases
# see https://www.talos.dev/v1.7/introduction/support-matrix/
variable "talos_version" {
  type = string
  # renovate: datasource=docker depName=ghcr.io/siderolabs/installer
  default = "1.12.1"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)+", var.talos_version))
    error_message = "Must be a version number."
  }
}

# see https://github.com/siderolabs/kubelet/pkgs/container/kubelet
# see https://www.talos.dev/v1.7/introduction/support-matrix/
variable "kubernetes_version" {
  type = string
  # renovate: datasource=docker depName=ghcr.io/siderolabs/kubelet
  default = "1.34.3"
  validation {
    condition     = can(regex("^\\d+(\\.\\d+)+", var.kubernetes_version))
    error_message = "Must be a version number."
  }
}

variable "node_distribution" {
  type = object({
    controllers = list(object({
      node    = string
      cpu     = number
      memory  = number
      address = string
      storage = object({
        os = object({
          storage_pool = string
          size         = number
        })
        datastore = optional(object({
          storage_pool = string
          size         = number
        }), null)
      })

    }))
    workers = list(object({
      node    = string
      cpu     = number
      memory  = number
      address = string
      storage = object({
        os = object({
          storage_pool = string
          size         = number
        })
        datastore = optional(object({
          storage_pool = string
          size         = number
        }), null)
      })

      gpu = optional(object({
        id = string
      }), null)
    }))
  })
  description = "A collection of node definitions to define which node is created on which proxmox node. A cluster should have at least one controller and one worker. In our current setup, the first controller must be placed on the same node as the OPNsense VM for the cluster init to work."
}

variable "use_nvidia_gpu" {
  description = "Does the cluster have at least one node with a NVIDIA GPU attached to it"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "example"
}

variable "cluster_vip" {
  description = "The VIP for the management of the Talos cluster"
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

variable "schedule_pods_on_control_plane_nodes" {
  description = "Whether or not every pods can be scheduled on control plane nodes"
  type        = bool
  default     = false
}

variable "cluster_prefix" {
  type    = string
  default = "talos"
}

variable "cluster_lan_gateway" {
  description = "The gateway for the load balancer subnet"
  type        = string
  default     = "10.64.64.255"
}

variable "registry_mirror_url" {
  description = "URL to be used as base for registry mirrors in the cluster (zot compatible)"
  type        = string
  default     = ""
}
