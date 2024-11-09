resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}
