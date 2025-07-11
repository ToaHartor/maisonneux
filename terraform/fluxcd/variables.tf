# General

variable "admin_email" {
  type        = string
  description = "Email of cluster admin (used for Let's encrypt)"
}

variable "main_domain" {
  type        = string
  description = "Main domain name"
}

variable "second_domain" {
  type        = string
  description = "Secondary domain name"
  default     = ""
}

variable "storage" {
  type = object({
    fastdata = string
  })
  description = "Storage classes name (in k8s)"
}

# Fluxcd credentials

variable "flux_git_user" {
  type = string
}

variable "flux_git_token" {
  type = string
}

variable "flux_git_branch" {
  type = string
}

variable "flux_git_remote_protocol" {
  type    = string
  default = "https"
}
variable "flux_git_remote_domain" {
  type    = string
  default = "github.com"
}
variable "flux_git_remote_port" {
  type    = string
  default = "443"
}
variable "flux_git_repository" {
  type = string
}


# MinIO
variable "minio_access_key" {
  type        = string
  description = "External MinIO admin access key"
}

variable "minio_secret_key" {
  type        = string
  description = "External MinIO admin secret key"
}

variable "minio_access_url" {
  type        = string
  description = "External MinIO access URL (format 'localhost:9000')"
}

# TrueNAS
variable "truenas_vm_host" {
  type        = string
  description = "TrueNAS host or IP"
}

variable "truenas_nfs_paths" {
  type = object({
    media_1   = string
    download  = string
    immich    = string
    paperless = string
    seafile   = string
  })
  description = "TrueNAS list of NFS paths"
}

# OVH
variable "ovh_endpoint_name" {
  type        = string
  description = "Endpoint name for OVH challenge (e.g. ovh-eu)"
}

variable "ovh_application_key" {
  type        = string
  description = "OVH application key"
}

variable "ovh_application_secret" {
  type        = string
  description = "OVH application secret"
}

variable "ovh_consumer_key" {
  type        = string
  description = "OVH consumer key"
}

# K8S LB IPs
variable "k8s_lb_traefik_ip" {
  type        = string
  description = "IP address of Traefik LB (must be in LB subnet)"
  validation {
    condition     = can(cidrnetmask("${var.k8s_lb_traefik_ip}/32"))
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}

variable "k8s_lb_otelcol_ip" {
  type        = string
  description = "IP address of Otel collector LB (must be in LB subnet)"
  validation {
    condition     = can(cidrnetmask("${var.k8s_lb_otelcol_ip}/32"))
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}
