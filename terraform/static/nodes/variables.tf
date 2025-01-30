variable "data_disks" {
  type = list(object({
    path_in_datastore = string
    size              = number
  }))
  description = "List of disks to attach"
}

variable "proxmox_node_name" {
  type        = string
  description = "Proxmox node name"
}
