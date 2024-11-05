resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_namespace" "operators" {
  metadata {
    name = "operators"
  }
}
