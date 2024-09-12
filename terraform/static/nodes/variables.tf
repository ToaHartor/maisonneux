variable "data_disks" {
  type = list(object({
    path_in_datastore = string
    size              = number
  }))
  description = "List of disks to attach"
}
