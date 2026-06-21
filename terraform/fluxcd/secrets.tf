resource "kubernetes_secret_v1" "flux_git_credentials" {
  metadata {
    name      = "flux-git-credentials"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name
  }

  type = "Opaque"

  # We need to provide git credentials for private Github pipelines
  data = merge(var.flux_git_ssh_config != null ? {
    "identity"     = var.flux_git_ssh_config.private_key
    "identity.pub" = var.flux_git_ssh_config.public_key
    "known_hosts"  = var.flux_git_ssh_config.known_hosts
    } : {}
    ,
    {
      "username" = var.flux_git_user
      "password" = var.flux_git_token
    }
  )
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

resource "kubernetes_secret_v1" "external_github_sa" {
  metadata {
    name      = "external-github-sa"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    username                = var.github_user
    password                = var.github_password
    githubAppID             = var.github_app_config.app_id
    githubAppInstallationID = var.github_app_config.installation_id
    githubAppPrivateKey     = var.github_app_config.private_key
  }
}

resource "kubernetes_secret_v1" "external_garage_secrets" {
  metadata {
    name      = "external-garage-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    garage_rpc_secret  = var.garage_rpc_secret
    garage_admin_token = var.garage_admin_token
  }
}

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

resource "kubernetes_secret_v1" "external_gluetun_config" {
  metadata {
    name      = "external-gluetun-config"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    private_key = var.gluetun_wireguard_privatekey
  }
}

resource "kubernetes_secret_v1" "external_hf_config" {
  metadata {
    name      = "external-hf-config"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    hf_token = var.huggingface_token
  }
}

resource "kubernetes_secret_v1" "external_tachi_config" {
  metadata {
    name      = "external-tachi-config"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    captcha_token      = var.tachi_config.captcha_token
    captcha_secret_key = var.tachi_config.captcha_secret_key
    cdn_web_location   = var.tachi_config.cdn_web_location
    cdn_endpoint       = var.tachi_config.cdn_endpoint
    cdn_bucket         = var.tachi_config.cdn_bucket
    cdn_region         = var.tachi_config.cdn_region
    cdn_access_key     = var.tachi_config.cdn_access_key
    cdn_secret_key     = var.tachi_config.cdn_secret_key
  }
}

resource "kubernetes_secret_v1" "external_forgejo_secrets" {
  metadata {
    name      = "external-forgejo-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    uuid                = var.forgejo_runner.uuid
    token               = var.forgejo_runner.token
    signing_private_key = var.forgejo_signing.private_key
    signing_public_key  = var.forgejo_signing.public_key
  }
}

resource "kubernetes_secret_v1" "external_sources_secrets" {
  metadata {
    name      = "external-sources-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
  type = "Opaque"

  data = {
    github_pat         = var.external_sources_tokens.github_pat
    dockerhub_username = var.external_sources_tokens.dockerhub_username
    dockerhub_token    = var.external_sources_tokens.dockerhub_token
  }
}
