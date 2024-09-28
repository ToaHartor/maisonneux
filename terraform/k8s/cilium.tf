locals {
  # see https://docs.cilium.io/en/stable/network/lb-ipam/
  # see https://docs.cilium.io/en/stable/network/l2-announcements/
  # see the CiliumL2AnnouncementPolicy type at https://github.com/cilium/cilium/blob/v1.16.0/pkg/k8s/apis/cilium.io/v2alpha1/l2announcement_types.go#L23-L42
  # see the CiliumLoadBalancerIPPool type at https://github.com/cilium/cilium/blob/v1.16.0/pkg/k8s/apis/cilium.io/v2alpha1/lbipam_types.go#L23-L47
  cilium_external_lb_manifests = [
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumL2AnnouncementPolicy"
      metadata = {
        name = "external"
      }
      spec = {
        loadBalancerIPs = true
        interfaces = [
          "eth0",
        ]
        nodeSelector = {
          matchExpressions = [
            {
              key      = "node-role.kubernetes.io/control-plane"
              operator = "DoesNotExist"
            },
          ]
        }
      }
    },
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumLoadBalancerIPPool"
      metadata = {
        name = "external"
      }
      spec = {
        blocks = [
          {
            start = cidrhost(var.cluster_node_network, var.cluster_node_network_load_balancer_first_hostnum)
            stop  = cidrhost(var.cluster_node_network, var.cluster_node_network_load_balancer_last_hostnum)
          },
        ]
      }
    },
  ]
  cilium_external_lb_manifest = join("---\n", [for d in local.cilium_external_lb_manifests : yamlencode(d)])

  # https://artifacthub.io/packages/helm/cilium/cilium
  cilium_chart_values = {
    ipam = {
      mode = "cluster-pool" # "kubernetes"
      operator = {
        clusterPoolIPv4MaskSize = 24
        clusterPoolIPv4PodCIDRList = var.cluster_pod_cidr
      }
    }
    k8s = {
      requireIPv4PodCIDR = true
    }
    securityContext = {
      capabilities = {
        ciliumAgent = ["CHOWN","KILL","NET_ADMIN","NET_RAW","IPC_LOCK","SYS_ADMIN","SYS_RESOURCE","DAC_OVERRIDE","FOWNER","SETGID","SETUID"]
        cleanCiliumState = ["NET_ADMIN","SYS_ADMIN","SYS_RESOURCE"]
      }
    }
    cgroup = {
      autoMount = {
        enabled = false
      }
      hostRoot = "/sys/fs/cgroup"
    }
    k8sServiceHost = "localhost"
    k8sServicePort = local.common_machine_config.machine.features.kubePrism.port
    kubeProxyReplacement = true
    # ipv4NativeRoutingCIDR = var.cluster_pod_cidr
    l2announcements = {
      enabled = true
    }
    devices = ["eth0"]
    ingressController = {
      enabled = true
      default = true
      loadbalancerMode = "shared"
      enforceHttps = false
    }
    envoy = {
      enabled = true
    }
    hubble = {
      relay = {
        enabled = true
      }
      ui = {
        enabled = true
      }
    }
  }
}

// see https://www.talos.dev/v1.7/kubernetes-guides/network/deploying-cilium/#method-4-helm-manifests-inline-install
// see https://docs.cilium.io/en/stable/network/servicemesh/ingress/
// see https://docs.cilium.io/en/stable/gettingstarted/hubble_setup/
// see https://docs.cilium.io/en/stable/gettingstarted/hubble/
// see https://docs.cilium.io/en/stable/helm-reference/#helm-reference
// see https://github.com/cilium/cilium/releases
// see https://github.com/cilium/cilium/tree/v1.16.0/install/kubernetes/cilium
// see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template
data "helm_template" "cilium" {
  namespace  = "kube-system"
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  # renovate: datasource=helm depName=cilium registryUrl=https://helm.cilium.io
  version      = "1.16.2"
  kube_version = var.kubernetes_version
  api_versions = []
  values = [yamlencode(local.cilium_chart_values)]
}
