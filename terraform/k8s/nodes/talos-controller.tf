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

# TODO : manage images containing nvidia drivers
data "http" "talos_factory_schematic_id" {
  url    = "https://factory.talos.dev/schematics"
  method = "POST"

  request_headers = {
    Content-type = "text/x-yaml"
  }
  request_body = file("../../../scripts/talos_schematic.yaml")
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud_image" {
  # Add the image on each node
  count        = length(local.proxmox_nodes)
  content_type = "iso"
  datastore_id = "local"
  node_name    = local.proxmox_nodes[count.index]

  file_name               = "talos-${var.talos_version}-nocloud-amd64-${terraform.workspace}.img"
  url                     = "https://factory.talos.dev/image/${jsondecode(data.http.talos_factory_schematic_id.response_body).id}/v${var.talos_version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}


resource "proxmox_virtual_environment_vm" "k8s-controller" {
  count           = length(local.controller_nodes)
  name            = local.controller_nodes[count.index].name
  node_name       = local.controller_nodes[count.index].config.node
  tags            = sort(["terraform", "talos", "k8s", "controller", "${terraform.workspace}"])
  stop_on_destroy = true
  bios            = "ovmf"
  machine         = "q35"
  scsi_hardware   = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  cpu {
    cores        = local.controller_nodes[count.index].config.cpu
    type         = "host"
    architecture = "x86_64"
  }

  memory {
    dedicated = local.controller_nodes[count.index].config.memory * 1024
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
    datastore_id = local.controller_nodes[count.index].config.storage.os.storage_pool
    file_format  = "raw"
    type         = "4m"
  }
  disk {
    datastore_id = local.controller_nodes[count.index].config.storage.os.storage_pool
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = local.controller_nodes[count.index].config.storage.os.size
    file_format  = "raw"
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud_image[index(local.proxmox_nodes, local.controller_nodes[count.index].config.node)].id
  }

  dynamic "disk" {
    # Add an additional disk only if this storage is defined in the node config
    for_each = local.controller_nodes[count.index].config.storage.datastore != null ? [1] : []
    content {
      datastore_id = local.controller_nodes[count.index].config.storage.datastore.storage_pool
      interface    = "scsi1"
      iothread     = true
      ssd          = true
      discard      = "on"
      size         = local.controller_nodes[count.index].config.storage.datastore.size
      file_format  = "raw"
    }
  }

  agent {
    enabled = true
    trim    = true
  }
  initialization {
    dns {
      servers = [var.cluster_lan_gateway]
    }
    ip_config {
      ipv4 {
        address = "${local.controller_nodes[count.index].address}/${var.cluster_subnet}"
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
        clusterName                    = var.cluster_name
        allowSchedulingOnControlPlanes = var.schedule_pods_on_control_plane_nodes
        // solves https://github.com/siderolabs/talos/issues/9980 for k8s 1.32+
        apiServer = {
          extraArgs = {
            feature-gates = "AuthorizeNodeWithSelectors=false"
          }
        }
        # Proxmox csi driver for storage
        externalCloudProvider = {
          enabled = true
          manifests = [
            # Talos CCM, install with daemonset
            "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/main/docs/deploy/cloud-controller-manager-daemonset.yml"
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
  count                       = length(local.controller_nodes)
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
        # Labels for csi-proxmox-driver
        nodeLabels = {
          "topology.kubernetes.io/region" = var.proxmox_cluster_name
          "topology.kubernetes.io/zone"   = local.controller_nodes[count.index].config.node
        }
      }
    }),
    # Add mount for linstor
    local.controller_nodes[count.index].config.storage.datastore != null ? yamlencode(local.linstor_mount_config) : ""
  ]
  depends_on = [
    proxmox_virtual_environment_vm.k8s-controller,
  ]
}
