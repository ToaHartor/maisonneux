# Variables from module nodes output
variable "deploy_env" {
  type        = string
  description = "Target environment to deploy the charts to"
}

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

variable "cluster_virtual_lb_pool" {
  description = "The subnet dedicated for load balancer IPs"
  type        = string
  default     = "10.64.64.0/24"
}

variable "cluster_lan_gateway" {
  description = "The gateway for the load balancer subnet"
  type        = string
  default     = "10.64.64.255"
}

# BGP config
variable "bgp_asn" {
  type        = number
  description = "BGP ASN for Cilium peer routing"
  default     = 65555
}

# OPNSense configuration
variable "opnsense_host" {
  type        = string
  description = "OPNSense VM IP address"
}

variable "opnsense_api_key" {
  type        = string
  description = "OPNSense root API key"
  sensitive   = true
}

variable "opnsense_api_secret" {
  type        = string
  description = "OPNSense root API secret"
  sensitive   = true
}

# K8S LB 
variable "opnsense_base_port_number" {
  type        = number
  description = "Starting port number on the router to expose services (e.g. value of 10000 will make the service with a base port of 80 be exposed on port 10080 on the router)"
}

