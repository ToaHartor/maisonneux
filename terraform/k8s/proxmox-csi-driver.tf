locals {
  proxmox_csi_cluster = {
    url          = "${var.proxmox_api_endpoint}/api2/json"
    insecure     = true
    token_id     = split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)[0]
    token_secret = split("=", proxmox_virtual_environment_user_token.kubernetes_csi_token.value)[1]
    region       = "datacenter"
  }
  # Helm values, based on https://github.com/sergelogvinov/proxmox-csi-plugin/tree/main/charts/proxmox-csi-plugin
  proxmox_csi_values = {
    config = {
      clusters = [
        local.proxmox_csi_cluster
      ]
    }
    storageClass = [
      {
        name = "proxmox-data-ext4"
        storage = var.proxmox_vm_storage
        reclaimPolicy = "Delete" # Retain
        fstype = "ext4"
      }
    ]
    node = {
      nodeSelector = {
        # It will work only with Talos CCM, remove it overwise
        "node.cloudprovider.kubernetes.io/platform" = "nocloud"
      }
      tolerations = [
        {
          operator = "Exists"
        }
      ]
    }
    nodeSelector = {
      "node-role.kubernetes.io/control-plane" = ""
    }

    tolerations = [
      {
        key = "node-role.kubernetes.io/control-plane"
        effect = "NoSchedule"
      }
    ]
  }
}

data "helm_template" "proxmox_csi" {
  namespace    = "kube-system" # "csi-proxmox"
  name         = "proxmox-csi-plugin"
  repository   = "oci://ghcr.io/sergelogvinov/charts"
  chart        = "proxmox-csi-plugin"
  # Version from https://github.com/sergelogvinov/proxmox-csi-plugin/blob/main/charts/proxmox-csi-plugin/Chart.yaml
  version      = "0.2.13"
  kube_version = var.kubernetes_version
  api_versions = []
  values       = [yamlencode(local.proxmox_csi_values)]
}
