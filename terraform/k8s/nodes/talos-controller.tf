# Local built image
# resource "proxmox_virtual_environment_file" "talos" {
#   content_type = "iso"
#   datastore_id = "local"
#   node_name    = var.proxmox_node_name
#   source_file {
#     path      = "../../../tmp/talos/talos-${var.talos_version}.qcow2"
#     file_name = "talos-${var.talos_version}.img"
#   }
# }

data "http" "talos_factory_schematic_id" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"

  request_headers = {
    Content-type = "text/x-yaml"
  }
  request_body = file("../../../scripts/talos_schematic.yaml")
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node_name

  file_name               = "talos-${var.talos_version}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/${jsondecode(data.http.talos_factory_schematic_id.response_body).id}/v${var.talos_version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}


resource "proxmox_virtual_environment_vm" "k8s-controller" {
  count           = var.controller_count
  name            = local.controller_nodes[count.index].name
  node_name       = var.proxmox_node_name
  tags            = sort(["terraform", "talos", "k8s", "controller"])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  cpu {
    cores        = 4
    type         = "host"
    architecture = "x86_64"
  }

  memory {
    dedicated = 6 * 1024
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
    datastore_id = var.proxmox_vm_storage
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = var.proxmox_vm_storage
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = var.cluster_os_storage
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image.id
  }
  agent {
    enabled = true
    trim    = true
  }
  initialization {
    ip_config {
      ipv4 {
        address = "${local.controller_nodes[count.index].address}/${var.cluster_subnet}"
        gateway = var.cluster_node_network_gateway
      }
    }
  }
  // TODO : passthrough vGPU
  # hostpci {
  #   device   = "hostpci0"
  #   id       = "0000:07:00.0"
  #   mapping  = null
  #   mdev     = "nvidia-47"
  #   pcie     = false
  #   rom_file = null
  #   rombar   = true
  #   xvga     = true
  # }
  lifecycle {
    ignore_changes = [
      disk[0].file_id
    ]
  }
}

data "talos_machine_configuration" "controller" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_secrets    = talos_machine_secrets.talos.machine_secrets
  machine_type       = "controlplane"
  talos_version      = "v${var.talos_version}"
  kubernetes_version = var.kubernetes_version
  examples           = false
  docs               = false
  config_patches = [
    yamlencode(local.common_machine_config),
    yamlencode({
      machine = {
        network = {
          interfaces = [
            # see https://www.talos.dev/v1.7/talos-guides/network/vip/
            {
              interface = "eth0"
              vip = {
                ip = var.cluster_vip
              }
            }
          ]
        }
        features = {
          # Enable Talos CCM
          kubernetesTalosAPIAccess = {
            enabled                     = true
            allowedRoles                = ["os:reader"]
            allowedKubernetesNamespaces = ["kube-system"]
          }
        }
        // Add the following for nvidia driver
        # sysctls = {
        #   "net.core.bpf_jit_harden" = 1
        # }
        # kernel = {
        #   modules = [
        #     { name = "nvidia" }, { name = "nvidia_uvm" }, { name = "nvidia_drm" }, { name = "nvidia_modeset" }
        #   ]
        # }
      }
    }),
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
        # Proxmox csi driver for storage
        externalCloudProvider = {
          enabled = true
          manifests = [
            # "https://raw.githubusercontent.com/sergelogvinov/proxmox-csi-plugin/main/docs/deploy/proxmox-csi-plugin-talos.yml",
            # Manifests for metrics server for HPA/VPA
            # see https://www.talos.dev/v1.7/kubernetes-guides/configuration/deploy-metrics-server/#install-during-bootstrap
            "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
            "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml",
            # Talos CCM
            "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/main/docs/deploy/cloud-controller-manager.yml"
          ]
        }
        inlineManifests = [
          # {
          #   name = "democratic-csi-truenas-iscsi"
          #   contents = join("---\n", [
          #     data.helm_template.democratic_csi_truenas_iscsi.manifest,
          #   ])
          # },
          # {
          #   name = "democratic-csi-truenas-nfs"
          #   contents = join("---\n", [
          #     data.helm_template.democratic_csi_truenas_nfs.manifest,
          #   ])
          # },
          # {
          #   name = "csi-s3"
          #   contents = join("---\n", [
          #     data.helm_template.csi_s3.manifest,
          #   ])
          # },
          # {
          #   name = "cilium"
          #   contents = join("---\n", [
          #     data.helm_template.cilium.manifest,
          #     "# Source cilium.tf\n${local.cilium_external_lb_manifest}",
          #   ])
          # },
          # {
          #   name = "nvidia-device-plugin"
          #   contents = join("---\n", [yamlencode(local.nvidia_runtime_resource),
          #     data.helm_template.nvidia_device_plugin.manifest,
          #   ])
          # },
        ],
      },
    }),
  ]
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/resources/machine_bootstrap
resource "talos_machine_bootstrap" "talos" {
  client_configuration = talos_machine_secrets.talos.client_configuration
  endpoint             = local.controller_nodes[0].address
  node                 = local.controller_nodes[0].address
  depends_on = [
    talos_machine_configuration_apply.controller,
  ]
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/resources/machine_configuration_apply
resource "talos_machine_configuration_apply" "controller" {
  count                       = var.controller_count
  client_configuration        = talos_machine_secrets.talos.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controller.machine_configuration
  endpoint                    = local.controller_nodes[count.index].address
  node                        = local.controller_nodes[count.index].address
  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = local.controller_nodes[count.index].name
        }
      }
    }),
  ]
  depends_on = [
    proxmox_virtual_environment_vm.k8s-controller,
  ]
}