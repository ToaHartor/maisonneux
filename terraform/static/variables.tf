# Common variables
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

// Data disks for module.nodes
variable "data_disks" {
  type = list(object({
    path_in_datastore = string
    size              = number
  }))
  description = "List of disks to attach"
  default     = []
}
