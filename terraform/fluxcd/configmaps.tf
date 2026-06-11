resource "kubernetes_config_map_v1" "general_config" {
  metadata {
    name      = "general-config"
    namespace = kubernetes_namespace_v1.flux_system.metadata[0].name
  }
  data = local.general_config
}
