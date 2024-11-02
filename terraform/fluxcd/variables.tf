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
