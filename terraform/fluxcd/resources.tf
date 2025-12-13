resource "kubernetes_secret_v1" "flux_git_credentials" {
  metadata {
    name      = "flux-git-credentials"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name
  }

  type = "Opaque"

  data = {
    "username" = var.flux_git_user
    "password" = var.flux_git_token
  }
}

# data "local_sensitive_file" "proxmox_csi_creds_file" {
#   filename = "${path.module}/../../tmp/proxmoxcsi.yaml"
# }

# resource "kubernetes_secret_v1" "proxmox_csi_creds" {
#   # Count = 1 if production env
#   # count = 1
#   metadata {
#     name      = "proxmox-csi-creds"
#     namespace = "kube-system"
#   }
#   type = "Opaque"

#   data = {
#     "config.yaml" = data.local_sensitive_file.proxmox_csi_creds_file.content
#   }
# }

resource "kubernetes_secret_v1" "external_minio_secrets" {
  metadata {
    name      = "external-minio-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    access_key = var.minio_access_key
    secret_key = var.minio_secret_key
  }
}

resource "kubernetes_secret_v1" "external_ovh_secrets" {
  metadata {
    name      = "external-ovh-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    admin_email        = var.admin_email
    endpoint_name      = var.ovh_endpoint_name
    application_key    = var.ovh_application_key
    application_secret = var.ovh_application_secret
    consumer_key       = var.ovh_consumer_key
  }
}

resource "kubernetes_config_map_v1" "general_config" {
  metadata {
    name      = "general-config"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name
  }
  data = local.general_config
}

resource "kubernetes_secret_v1" "external_smtp_config" {
  metadata {
    name      = "external-smtp-config"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    smtp_username = var.smtp_username
    smtp_token    = var.smtp_token
    smtp_server   = var.smtp_server
    smtp_port     = var.smtp_port
  }
}
