resource "kubernetes_namespace_v1" "flux_system" {
  metadata {
    name = "flux-system"
    annotations = {
      "kustomize.toolkit.fluxcd.io/prune" = "disabled"
    }
  }
  // FluxCD bootstrap adds several annotations and labels that are specific
  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      metadata[0].labels
    ]
  }
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
    annotations = {
      "kustomize.toolkit.fluxcd.io/prune" = "disabled"
    }
    labels = {
      "kustomize.toolkit.fluxcd.io/name"      = "system"
      "kustomize.toolkit.fluxcd.io/namespace" = "flux-system"
    }
  }
}
