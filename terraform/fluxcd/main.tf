terraform {
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
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
/*
# Cluster folders include
!/clusters/${terraform.workspace}
!/apps/
!/core/
!/platform/
!/system/
# Include helm charts folder as well
!/helm/
# Remove flux-system as well
clusters/**/flux-system/"
EOF
      }
    }
    kustomization = {
      spec = {
        prune = true
        force = true
        path  = "./clusters/${terraform.workspace}"
      }
    }
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
  version    = "1.10.0"

  # Note: Do not change the name or namespace of this resource. The below mimics the behaviour of "flux bootstrap".
  name      = "flux-system"
  namespace = "flux-system"

  values     = [yamlencode(local.flux_sync_helm_values)]
  depends_on = [helm_release.fluxcd]
}
