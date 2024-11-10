resource "kubernetes_secret" "flux_git_credentials" {
  metadata {
    name      = "flux-git-credentials"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }

  type = "Opaque"

  data = {
    "username" = var.flux_git_user
    "password" = var.flux_git_token
  }
}

data "local_sensitive_file" "proxmox_csi_creds_file" {
  filename = "${path.module}/../../tmp/proxmoxcsi.yaml"
}

resource "kubernetes_secret" "proxmox_csi_creds" {
  # Count = 1 if production env
  # count = 1
  metadata {
    name      = "proxmox-csi-creds"
    namespace = "kube-system"
  }
  type = "Opaque"

  data = {
    "config.yaml" = data.local_sensitive_file.proxmox_csi_creds_file.content
  }
}

resource "kubernetes_secret" "external_secrets" {
  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    minio_url        = var.minio_access_url
    minio_access_key = var.minio_access_key
    minio_secret_key = var.minio_secret_key
  }
}
