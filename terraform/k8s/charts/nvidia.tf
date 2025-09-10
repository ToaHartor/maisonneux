# Deploy the NVIDIA chart only if we use NVIDIA GPUs in the cluster
resource "helm_release" "nvidia_custom_resources" {
  depends_on = [helm_release.cilium_custom_resources]
  count      = var.use_nvidia_gpu ? 1 : 0

  name       = "nvidia-custom-resources"
  namespace  = "kube-system"
  repository = "https://helm-charts.wikimedia.org/stable/"
  chart      = "raw"
  version    = "0.3.0"
  values = [
    <<-EOF
    resources:
      - apiVersion: node.k8s.io/v1
        kind: RuntimeClass
        metadata:
          name: nvidia
        handler: nvidia
    EOF
  ]
}

resource "helm_release" "nvidia_device_plugin" {
  depends_on = [helm_release.nvidia_custom_resources]
  count      = var.use_nvidia_gpu ? 1 : 0

  namespace  = "kube-system"
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.17.4"
  # https://github.com/NVIDIA/k8s-device-plugin/blob/main/deployments/helm/nvidia-device-plugin/values.yaml
  values = []
  # values = [file("./nvidia_values.yaml")]
  wait = true
  set = [{
    name  = "runtimeClassName"
    value = "nvidia"
    },
    {
      name  = "gfd.enabled"
      value = "true"
    }
  ]
}
