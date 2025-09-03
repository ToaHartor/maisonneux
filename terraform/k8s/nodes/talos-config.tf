locals {
  controller_nodes = [
    for i in range(length(var.node_distribution.controllers)) : {
      name    = "${var.cluster_prefix}-c${i}-${terraform.workspace}"
      address = var.node_distribution.controllers[i].address
      config  = var.node_distribution.controllers[i]
    }
  ]
  worker_nodes = [
    for i in range(length(var.node_distribution.workers)) : {
      name    = "${var.cluster_prefix}-w${i}-${terraform.workspace}"
      address = var.node_distribution.workers[i].address
      config  = var.node_distribution.workers[i]
    }
  ]

  proxmox_nodes = distinct(
    concat(
      [for n in local.controller_nodes : n.config.node],
      [for n in local.worker_nodes : n.config.node]
    )
  )

  common_machine_config = {
    machine = {
      # NB the install section changes are only applied after a talos upgrade
      #    (which we do not do). instead, its preferred to create a custom
      #    talos image, which is created in the installed state.
      #install = {}
      # Add mirror to dev machine only if registry mirror url is set
      # We may also add the zot registry in the cluster (exposed at localhost:32000)
      # Finally, we add the actual registry as if no mirror is available, as the cluster should still be able to pull images
      registries = var.registry_mirror_url != "" ? {
        mirrors = {
          "docker.io" = {
            endpoints    = ["http://localhost:32000/v2/docker.io", "${var.registry_mirror_url}/docker.io", "https://docker.io/v2"]
            overridePath = true
          }
          "gcr.io" = {
            endpoints    = ["http://localhost:32000/v2/gcr.io", "${var.registry_mirror_url}/gcr.io", "https://gcr.io/v2"]
            overridePath = true
          }
          "ghcr.io" = {
            endpoints    = ["http://localhost:32000/v2/ghcr.io", "${var.registry_mirror_url}/ghcr.io", "https://ghcr.io/v2"]
            overridePath = true
          }
          "nvcr.io" = {
            endpoints    = ["http://localhost:32000/v2/nvcr.io", "${var.registry_mirror_url}/nvcr.io", "https://nvcr.io/v2"]
            overridePath = true
          }
          "registry.k8s.io" = {
            endpoints    = ["http://localhost:32000/v2/registry.k8s.io", "${var.registry_mirror_url}/registry.k8s.io", "https://registry.k8s.io/v2"]
            overridePath = true
          }
          "quay.io" = {
            endpoints    = ["http://localhost:32000/v2/quay.io", "${var.registry_mirror_url}/quay.io", "https://quay.io/v2"]
            overridePath = true
          }
          "registry.gitlab.com" = {
            endpoints    = ["http://localhost:32000/v2/registry.gitlab.com", "${var.registry_mirror_url}/registry.gitlab.com", "https://registry.gitlab.com/v2"]
            overridePath = true
          }
        }
      } : {}

      features = {
        # see https://www.talos.dev/v1.7/kubernetes-guides/configuration/kubeprism/
        # see talosctl -n $c0 read /etc/kubernetes/kubeconfig-kubelet | yq .clusters[].cluster.server
        # NB if you use a non-default CNI, you must configure it to use the
        #    https://localhost:7445 kube-apiserver endpoint.
        kubePrism = {
          enabled = true
          port    = 7445
        }
        hostDNS = {
          enabled              = true
          forwardKubeDNSToHost = false # Disable it as it conflicts with cilium's bpf.masquerade option https://github.com/cilium/cilium/issues/36761
          resolveMemberNames   = true
        }
      }

      logging = {
        destinations = [
          {
            endpoint = "udp://127.0.0.1:30555"
            format   = "json_lines"
          }
        ]
      }

      kernel = {
        modules = [
          # DRBD module for linstor and piraeus operator
          {
            name = "drbd"
            parameters = [
              "usermode_helper=disabled"
            ]
          },
          {
            name = "drbd_transport_tcp"
          },
          {
            name = "dm-thin-pool"
          }
        ]
      }
      # For metrics server
      kubelet = {
        extraArgs = {
          cloud-provider             = "external"
          rotate-server-certificates = true
          # To solve "failed to create pod sandbox : no space left on device"
          # https://serverfault.com/questions/1189137/talos-os-and-truecharts-failed-to-create-network-namespace-for-sandbox-error
          # feature-gates = "UserNamespacesSupport=true,UserNamespacesPodSecurityStandards=true"
        }
      }
      # sysctls = {
      #   "user.max_user_namespaces" = "11255"
      # }
      # nodeTaints = {
      #   "node.cilium.io/agent-not-ready" = "true:NoSchedule" # Taint nodes for cilium to check if it controls the node
      # }
    }
    cluster = {
      # see https://www.talos.dev/v1.7/talos-guides/discovery/
      # see https://www.talos.dev/v1.7/reference/configuration/#clusterdiscoveryconfig
      discovery = {
        enabled = false
        registries = {
          kubernetes = {
            # Deprecated as of k8s 1.32+
            disabled = true
          }
          service = {
            disabled = true
          }
        }
      }
      network = {
        cni = {
          name = "none" # As we install Cilium after
        }
        dnsDomain  = "cluster.local"
        podSubnets = [var.cluster_pod_cidr]
      }
      # Disable because of cilium
      proxy = {
        disabled = true
      }
      # Allow cert manager csi driver
      # Base from https://www.talos.dev/v1.7/reference/configuration/v1alpha1/config/#Config.cluster.apiServer.admissionControl.
      apiServer = {
        # User namespace feature
        # extraArgs = {
        #   feature-gates = "UserNamespacesSupport=true,UserNamespacesPodSecurityStandards=true"
        # }
        admissionControl = [
          {
            name = "PodSecurity"
            configuration = {
              exemptions = {
                namespaces = ["cert-manager", "flux-system", "piraeus-datastore", "opentelemetry", "velero"]
              }
            }
          }
        ]
      }
    }
  }
  linstor_mount_config = {
    machine = {
      nodeLabels = {
        "homelab/linstor-enabled" = "true"
      }
      # If using fileStorage in nodes
      # kubelet = {
      #   extraMounts = [
      #     {
      #       destination = "/var/mnt/linstor"
      #       type        = "bind"
      #       source      = "/var/mnt/linstor"
      #       options     = ["bind", "rshared", "rw"]
      #     }
      #   ]
      # }
      # disks = [
      #   {
      #     device = "/dev/sdb"
      #     partitions = [
      #       {
      #         mountpoint = "/var/mnt/linstor"
      #       }
      #     ]
      #   }
      # ]
    }
  }
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/data-sources/client_configuration
data "talos_client_configuration" "talos" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.talos.client_configuration
  endpoints            = [for node in local.controller_nodes : node.address]
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/data-sources/cluster_kubeconfig
resource "talos_cluster_kubeconfig" "talos" {
  client_configuration = talos_machine_secrets.talos.client_configuration
  endpoint             = local.controller_nodes[0].address
  node                 = local.controller_nodes[0].address
  depends_on = [
    talos_machine_bootstrap.talos,
  ]
}

// see https://registry.terraform.io/providers/siderolabs/talos/0.5.0/docs/resources/machine_secrets
resource "talos_machine_secrets" "talos" {
  talos_version = "v${var.talos_version}"
}
