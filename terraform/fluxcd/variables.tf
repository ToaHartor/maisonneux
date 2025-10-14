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

variable "cnpg_recovery" {
  type        = bool
  description = "Should the postgres clusters be restored (requires running cluster restore scripts)"
  default     = false
}

variable "use_letsencrypt_production_server" {
  type        = bool
  description = "Should the Let's Encrypt production server be used"
  default     = false
}

variable "use_nvidia_gpu" {
  description = "Does the cluster have at least one node with a NVIDIA GPU attached to it"
  type        = bool
  default     = false
}

# SMTP settings 

variable "smtp_username" {
  type        = string
  description = "Username to use to authenticate to the SMTP server"
}

variable "smtp_token" {
  type        = string
  description = "Password or token to use to authenticate to the SMTP server"
}

variable "smtp_server" {
  type        = string
  description = "SMTP server domain"
}

variable "smtp_port" {
  type        = number
  description = "Port of the SMTP server"
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

variable "minio_backup_bucket" {
  type        = string
  description = "External MinIO backup bucket"
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
    minio     = string
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

# K8S LB
variable "is_internet_ingress" {
  type        = bool
  description = "Is the ingress domain reachable on internet. If yes, ports will not appear in the referenced ingress domain (example.com instead of example.com:10080)"
}


variable "opnsense_base_port_number" {
  type        = number
  description = "Starting port number on the router to expose services (e.g. value of 10000 will make the service with a base port of 80 be exposed on port 10080 on the router)"
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

variable "k8s_lb_influxdb_ip" {
  type        = string
  description = "IP address of InfluxDB collector in VictoriaMetrics (must be in LB subnet)"
  validation {
    condition     = can(cidrnetmask("${var.k8s_lb_influxdb_ip}/32"))
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}

# Legacy VM options, to be deleted when fully migrated
variable "legacy_vm_ip" {
  type        = string
  description = "IP address of the VM hosting the legacy services"
  validation {
    condition     = can(cidrnetmask("${var.legacy_vm_ip}/32"))
    error_message = "Must be a valid IPv4 CIDR block address."
  }
}
