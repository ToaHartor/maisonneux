# Deploy the NVIDIA chart only if we use NVIDIA GPUs in the cluster
resource "helm_release" "nvidia_custom_resources" {
  depends_on = [helm_release.cilium_custom_resources]
  count      = var.use_nvidia_gpu ? 1 : 0

  name       = "nvidia-custom-resources"
  namespace  = "kube-system"
  repository = "https://helm-charts.wikimedia.org/stable/"
  chart      = "raw"
  # Waiting for https://github.com/hashicorp/terraform-provider-helm/issues/1689 (next release)
  # upgrade_install = true
  version = "0.3.0"
  values = [
    <<-EOF
    resources:
      - apiVersion: node.k8s.io/v1
        kind: RuntimeClass
        metadata:
          name: nvidia
        handler: nvidia
      - apiVersion: scheduling.k8s.io/v1
        kind: PriorityClass
        metadata:
          name: nvidia
        value: 100000000
        globalDefault: false
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
  # upgrade_install = true
  version = "0.18.0"
  # https://github.com/NVIDIA/k8s-device-plugin/blob/main/deployments/helm/nvidia-device-plugin/values.yaml
  values = [
    <<-EOF
    gfd:
      enabled: true
    runtimeClassName: nvidia
    config:
      map:
        default: |-
          version: v1
          flags:
            migStrategy: none
          sharing:
            timeSlicing:
              renameByDefault: false
              failRequestsGreaterThanOne: false
              resources:
                - name: nvidia.com/gpu
                  replicas: 5
    EOF
  ]
  wait = true
}
