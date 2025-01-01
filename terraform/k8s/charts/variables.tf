# Variables from module nodes output
variable "kubeprism_port" {
  type        = number
  description = "Kubeprism port from nodes deployment"
  default     = 0
}

variable "controllers" {
  type        = string
  description = "String with the list of controllers from nodes deployment"
}

variable "workers" {
  type        = string
  description = "String with the list of workers from nodes deployment"
}

# Cluster variables

variable "cluster_vip" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "192.168.1.79"
}

variable "cluster_node_network" {
  description = "The IP network prefix of the cluster nodes"
  type        = string
  default     = "192.168.1.0/24"
}

variable "cluster_pod_cidr" {
  description = "CIDR of IP address of pods inside the cluster"
  type        = string
  default     = "10.244.0.0/16"
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
