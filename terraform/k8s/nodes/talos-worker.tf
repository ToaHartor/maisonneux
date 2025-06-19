# see https://registry.terraform.io/providers/bpg/proxmox/0.62.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "k8s-worker" {
  count           = length(local.worker_nodes)
  name            = local.worker_nodes[count.index].name
  node_name       = local.worker_nodes[count.index].config.node
  tags            = sort(["terraform", "talos", "k8s", "worker", "${terraform.workspace}"])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  cpu {
    architecture = "x86_64"
    type         = "host"
    cores        = local.worker_nodes[count.index].config.cpu
  }

  memory {
    dedicated = local.worker_nodes[count.index].config.memory * 1024
  }

  vga {
    type = "qxl"
  }
  network_device {
    bridge = "vmbr0"
  }
  tpm_state {
    version = "v2.0"
  }
  efi_disk {
    datastore_id = local.worker_nodes[count.index].config.storage.os.storage_pool
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = local.worker_nodes[count.index].config.storage.os.storage_pool
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = local.worker_nodes[count.index].config.storage.os.size
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image[index(local.proxmox_nodes, local.worker_nodes[count.index].config.node)].id
  }

  dynamic "disk" {
    # Add an additional disk only if this storage is defined in the node config
    for_each = local.worker_nodes[count.index].config.storage.datastore != null ? [1] : []
    content {
      datastore_id = local.worker_nodes[count.index].config.storage.datastore.storage_pool
      interface    = "scsi1"
      iothread     = true
      ssd          = true
      discard      = "on"
      size         = local.worker_nodes[count.index].config.storage.datastore.size
      file_format  = "raw"
    }
  }

  agent {
    enabled = true
    trim    = true
  }


  dynamic "hostpci" {
    # Add GPU binding if defined in node config
    for_each = local.worker_nodes[count.index].config.gpu != null ? [1] : []

    content {
      device  = "hostpci0"
      id      = local.worker_nodes[count.index].config.gpu.id # "0000:08:00.0"
      mapping = null
      # mdev     = "nvidia-47"
      pcie     = false
      rom_file = null
      rombar   = true
      xvga     = true
    }

  }
  initialization {
    dns {
      servers = [var.cluster_lan_gateway]
    }
    ip_config {
      ipv4 {
        address = "${local.worker_nodes[count.index].address}/${var.cluster_subnet}"
        gateway = var.cluster_node_network_gateway
      }
    }
  }

  lifecycle {
    ignore_changes = [
      disk[0].file_id
    ]
  }
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/data-sources/machine_configuration
data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_secrets    = talos_machine_secrets.talos.machine_secrets
  machine_type       = "worker"
  talos_version      = "v${var.talos_version}"
  kubernetes_version = var.kubernetes_version
  examples           = false
  docs               = false
  config_patches = [
    yamlencode(local.common_machine_config),
  ]
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/resources/machine_configuration_apply
resource "talos_machine_configuration_apply" "worker" {
  count                       = length(local.worker_nodes)
  client_configuration        = talos_machine_secrets.talos.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  endpoint                    = local.worker_nodes[count.index].address
  node                        = local.worker_nodes[count.index].address
  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = local.worker_nodes[count.index].name
        }
        # Labels to identify proxmox nodes
        nodeLabels = {
          "topology.kubernetes.io/region" = var.proxmox_cluster_name
          "topology.kubernetes.io/zone"   = local.worker_nodes[count.index].config.node
        }
      }
    }),
    # Add mount for linstor
    local.worker_nodes[count.index].config.storage.datastore != null ? yamlencode(local.linstor_mount_config) : ""
  ]
  depends_on = [
    proxmox_virtual_environment_vm.k8s-worker,
  ]
}
