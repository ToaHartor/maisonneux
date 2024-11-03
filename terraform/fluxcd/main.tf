terraform {
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = "2.14.1"
    }
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
  }
}

locals {
  # see https://artifacthub.io/packages/helm/fluxcd-community/flux2-sync
  flux_sync_helm_values = {
    gitRepository = {
      spec = {
        url = "${var.flux_git_remote_protocol}://${var.flux_git_remote_domain}:${var.flux_git_remote_port}/${var.flux_git_repository}.git"
        secretRef = {
          name = "flux-git-credentials"
        }
        ref = {
          branch = var.flux_git_branch
        }
        interval = "1m"
        ignore   = <<EOF
# Ignore all folders, but include the ones with cluster resources
./*
# Cluster folders include
!./clusters
!./apps
!./core
!./platform
!./system
EOF
      }
    }
    kustomization = {
      spec = {
        path = "./clusters/staging"
      }
    }
  }
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

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

# example from https://github.com/fluxcd/terraform-provider-flux/blob/main/examples/helm-install/main.tf
resource "helm_release" "fluxcd" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  version    = "2.14.0"
  name       = "flux2"
  namespace  = "flux-system"

  depends_on = [kubernetes_secret.flux_git_credentials]
}

resource "helm_release" "fluxcd_sync" {
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2-sync"
  version    = "1.8.2"

  # Note: Do not change the name or namespace of this resource. The below mimics the behaviour of "flux bootstrap".
  name      = "flux-system"
  namespace = "flux-system"

  values     = [yamlencode(local.flux_sync_helm_values)]
  depends_on = [helm_release.fluxcd]
}
