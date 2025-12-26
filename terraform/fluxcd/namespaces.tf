resource "kubernetes_namespace_v1" "flux_system" {
  metadata {
    name = "flux-system"
    annotations = {
      "kustomize.toolkit.fluxcd.io/prune" = "disabled"
    }
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
    annotations = {
      "kustomize.toolkit.fluxcd.io/prune" = "disabled"
    }

  }
}
