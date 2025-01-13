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

resource "kubernetes_secret" "external_minio_secrets" {
  metadata {
    name      = "external-minio-secrets"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    access_key = var.minio_access_key
    secret_key = var.minio_secret_key
  }
}

resource "kubernetes_secret" "external_ovh_secrets" {
  metadata {
    name      = "external-ovh-secrets"
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
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

resource "kubernetes_config_map" "general_config" {
  metadata {
    name      = "general-config"
    namespace = kubernetes_namespace.flux_system.metadata[0].name
  }
  data = {
    "environment"      = terraform.workspace
    "minio_url"        = var.minio_access_url
    "main_domain"      = var.main_domain
    "secondary_domain" = var.second_domain
    "fastdata_storage" = var.storage.fastdata
    "git_repo_url"     = local.flux_sync_helm_values.gitRepository.spec.url
    "git_branch"       = var.flux_git_branch
  }
}

