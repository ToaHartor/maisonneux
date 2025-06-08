output "talosconfig" {
  value     = data.talos_client_configuration.talos.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.talos.kubeconfig_raw
  sensitive = true
}

output "controllers" {
  value = join(",", [for node in local.controller_nodes : node.address])
}

output "workers" {
  value = join(",", [for node in local.worker_nodes : node.address])
}

output "kubeprism_port" {
  value = local.common_machine_config.machine.features.kubePrism.port
}

# output "proxmox_csi_account" {
#   value     = yamlencode(local.proxmox_csi_cluster)
#   sensitive = true
# }
