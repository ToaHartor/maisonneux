# see https://registry.terraform.io/providers/bpg/proxmox/0.62.0/docs/resources/virtual_environment_vm
resource "proxmox_virtual_environment_vm" "k8s-worker" {
  count           = var.worker_count
  name            = local.worker_nodes[count.index].name
  node_name       = "datacenter"
  tags            = sort(["terraform", "talos", "k8s", "worker"])
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
    cores        = 4
  }

  memory {
    dedicated = 4 * 1024
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
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = var.cluster_os_storage
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_file.talos.id
  }

  agent {
    enabled = true
    trim    = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.worker_nodes[count.index].address}/${var.cluster_subnet}"
        gateway = var.cluster_node_network_gateway
      }
    }
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
  count                       = var.worker_count
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
      }
    }),
  ]
  depends_on = [
    proxmox_virtual_environment_vm.k8s-worker,
  ]
}
