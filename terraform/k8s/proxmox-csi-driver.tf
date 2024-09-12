locals {
  proxmox_csi_cluster = {
    url          = "${var.proxmox_api_endpoint}/api2/json"
    insecure     = true
    token_id     = split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)[0]
    token_secret = split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)[1]
    region       = "datacenter"
  }
}


data "helm_template" "proxmox_csi" {
  namespace    = "kube-system" # "csi-proxmox"
  name         = "proxmox-csi-plugin"
  repository   = "oci://ghcr.io/sergelogvinov/charts"
  chart        = "proxmox-csi-plugin"
  version      = "0.2.9"
  kube_version = var.kubernetes_version
  api_versions = []
  # Helm values, based on https://github.com/sergelogvinov/proxmox-csi-plugin/tree/main/charts/proxmox-csi-plugin
  set {
    name  = "config.clusters[0].url"
    value = local.proxmox_csi_cluster.url
  }
  set {
    name  = "config.clusters[0].insecure"
    value = local.proxmox_csi_cluster.insecure
  }
  set {
    name  = "config.clusters[0].token_id"
    value = local.proxmox_csi_cluster.token_id
  }
  set {
    name  = "config.clusters[0].token_secret"
    value = local.proxmox_csi_cluster.token_secret
  }
  set {
    name  = "config.clusters[0].region"
    value = local.proxmox_csi_cluster.region
  }
  # Storage class
  set {
    name  = "storageClass[0].name"
    value = "proxmox-data-ext4"
  }
  set {
    name  = "storageClass[0].storage"
    value = var.proxmox_vm_storage
  }
  set {
    name  = "storageClass[0].reclaimPolicy"
    value = "Delete" # Retain
  }
  set {
    name  = "storageClass[0].fstype"
    value = "ext4"
  }
  # Node selector
  set {
    name  = "node.nodeSelector"
    value = ""
  }
  set {
    name  = "node.tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "nodeSelector.node-role\\.kubernetes\\.io/control-plane"
    value = ""
  }
  set {
    name  = "tolerations[0].key"
    value = "node-role.kubernetes.io/control-plane"
  }
  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }
}
