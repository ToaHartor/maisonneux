locals {
  # https://artifacthub.io/packages/helm/cilium/cilium    
  cilium_chart_values = {
    ipam = {
      mode = "kubernetes"
      operator = {
        rollOutPods = true
        replicas    = 3
        # clusterPoolIPv4MaskSize    = 20
        # clusterPoolIPv4PodCIDRList = var.cluster_pod_cidr
        resources = {
          limits = {
            cpu    = "500m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "126Mi"
          }
        }

        # prometheus = {
        #   enabled = true
        # }
      }
    }

    bpf = {
      # datapathMode      = "netkit" # Not working even with Talos 1.19.1 (kernel 6.12)
      masquerade = true
      tproxy     = true
      # vlanBypass        = [0]
      hostLegacyRouting = false # Enable until compatibility is improved for 1.16.5+
    }

    ipv4NativeRoutingCIDR = var.cluster_pod_cidr

    endpointRoutes = {
      enabled = true
    }

    # -- Install Iptables rules to skip netfilter connection tracking on all pod
    # traffic. This option is only effective when Cilium is running in direct
    # routing and full KPR mode. Moreover, this option cannot be enabled when Cilium
    # is running in a managed Kubernetes environment or in a chained CNI setup.
    installNoConntrackIptablesRules = true
    # -- Enable bandwidth manager to optimize TCP and UDP workloads and allow
    # for rate-limiting traffic from individual Pods with EDT (Earliest Departure
    # Time) through the "kubernetes.io/egress-bandwidth" Pod annotation.
    bandwidthManager = {
      # Disable it according to https://github.com/siderolabs/talos/issues/8836#issuecomment-2159127683 if using cilium 1.16.5+
      # and enable bpf.hostLegacyRouting
      enabled = true
      bbr     = true
    }
    # -- Enables IPv4 BIG TCP support which increases maximum IPv4 GSO/GRO limits for nodes and pods
    # Not supported with bpf.hostLegacyRouting
    enableIPv4BIGTCP = true

    ipv4 = {
      enabled = true
    }
    ipv6 = {
      enabled = false
    }

    # Enabled by kubeProxyReplacement
    # socketLB = {
    #   enabled = true
    # }

    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
    cgroup = {
      autoMount = {
        enabled = false
      }
      hostRoot = "/sys/fs/cgroup"
    }
    k8sServiceHost       = "localhost"
    k8sServicePort       = var.kubeprism_port
    kubeProxyReplacement = true
    autoDirectNodeRoutes = true
    routingMode          = "native"

    rollOutCiliumPods = true
    resources = {
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
      requests = {
        cpu    = "200m"
        memory = "512Mi"
      }
    }

    # Increase rate limit when doing L2 announcements
    k8sClientRateLimit = {
      qps   = 20
      burst = 100
    }

    bgpControlPlane = {
      enabled = true
    }

    l2announcements = {
      enabled   = false # enable if no bgp
      interface = "eth0"
    }

    # Enabled by kubeProxyReplacement
    # externalIPs = {
    #   enabled = true
    # }

    loadBalancer = {
      # https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#maglev-consistent-hashing
      algorithm    = "maglev"
      mode         = "hybrid" # https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/#direct-server-return-dsr
      acceleration = "best-effort"
      # TODO : L7 is handled by Traefik
      # l7 = {
      #   backend = "envoy"
      # }
    }

    # maglev = {
    #   hashSeed = "" # TODO : base64-encoded 12 byte-random number
    # }

    nodeIPAM = {
      enabled = false
    }

    gatewayAPI = {
      enabled           = false
      enableAlpn        = false
      enableAppProtocol = false
    }


    devices = ["eth0"]
    ingressController = {
      enabled          = false
      default          = false
      loadbalancerMode = "shared"
      enforceHttps     = false
      # service = {
      #   annotations = {
      #     #     "io.cilium/lb-ipam-ips" = var.cluster_vip
      #   }
      # }
    }

    debug = {
      enabled = true
    }

    envoyConfig = {
      enabled = false
    }

    envoy = {
      enabled     = false # TODO : we try to use Traefik for that
      rollOutPods = true
      securityContext = {
        capabilities = {
          keepCapNetBindService = true
          envoy                 = ["NET_ADMIN", "NET_BIND_SERVICE", "PERFMON", "BPF"] # "SYS_ADMIN"
        }
      }
      debug = {
        admin = {
          enabled = true
        }
      }
    }
    hubble = {
      relay = {
        enabled     = true
        rollOutPods = true
      }
      ui = {
        enabled     = true
        rollOutPods = true
      }
      # metrics = {
      #   enableOpenMetrics = true
      #   enabled = ["dns", "drop", "tcp", "flow", "icmp", "http"]
      # }
    }
    # prometheus = {
    #   enabled = true
    # }

    # Hardening
    # policyEnforcementMode = "always" # Enforce network policies
    # hostFirewall = {
    #   enabled = true # Enable host policies (host-level network policies)
    # }
    # extraConfig = {
    #   allow-localhost = "policy" # Enforce policies for node-local traffic as well
    # }

    # Audit mode
    # policyAuditMode = true
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
# data "helm_template" "cilium" {
resource "helm_release" "cilium" {
  depends_on = [data.http.wait_k8sapi]
  namespace  = "kube-system"
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.16.4" # 1.16.5 has issues => https://github.com/cilium/cilium/issues/36761
  values     = [yamlencode(local.cilium_chart_values)]
  wait       = false # Do not wait for resources as the chart is designed like this

}

# Nodes become ready when CNI is established, so this checks if cilium install worked correctly
data "talos_cluster_health" "k8s_network_health" {
  depends_on = [helm_release.cilium, ansible_playbook.configure_bgp]
  client_configuration = {
    ca_certificate     = local.talosconfig.ca
    client_certificate = local.talosconfig.crt
    client_key         = local.talosconfig.key
  }

  control_plane_nodes = split(",", var.controllers)
  worker_nodes        = split(",", var.workers)
  endpoints           = local.talosconfig.controlplanes
  timeouts = {
    read = "10m"
  }
}

# Additional resources which need Cilium CRDs to be deployed
# see https://docs.cilium.io/en/stable/network/lb-ipam/
# see https://docs.cilium.io/en/stable/network/l2-announcements/
# see the CiliumL2AnnouncementPolicy type at https://github.com/cilium/cilium/blob/v1.16.0/pkg/k8s/apis/cilium.io/v2alpha1/l2announcement_types.go#L23-L42
# see the CiliumLoadBalancerIPPool type at https://github.com/cilium/cilium/blob/v1.16.0/pkg/k8s/apis/cilium.io/v2alpha1/lbipam_types.go#L23-L47
# Following suggestion from https://github.com/hashicorp/terraform-provider-kubernetes/issues/1380#issuecomment-1833651699
resource "helm_release" "cilium_custom_resources" {
  depends_on = [data.talos_cluster_health.k8s_network_health]

  name       = "cilium-custom-resources"
  namespace  = "kube-system"
  repository = "https://helm-charts.wikimedia.org/stable/"
  chart      = "raw"
  version    = "0.3.0"
  values = [
    <<-EOF
    resources:
      - apiVersion: "cilium.io/v2alpha1"
        kind: "CiliumLoadBalancerIPPool"
        metadata:
          name: "external"
        spec:
          blocks:
            - cidr: ${var.cluster_virtual_lb_pool}
      - apiVersion: cilium.io/v2alpha1
        kind: CiliumBGPAdvertisement
        metadata:
          name: bgp-advertisements
          namespace: kube-system
          labels:
            advertise: bgp
        spec:
          advertisements:
            - advertisementType: "Service"
              service:
                addresses:
                  # - ClusterIP
                  # - ExternalIP
                  - LoadBalancerIP
              selector:
                matchExpressions:
                  - { key: homelab/public-service, operator: In, values: [ 'true' ] }

      - apiVersion: cilium.io/v2alpha1
        kind: CiliumBGPPeerConfig
        metadata:
          name: peer-config
          namespace: kube-system
        spec:
          timers:
            holdTimeSeconds: 90
            keepAliveTimeSeconds: 30
            connectRetryTimeSeconds: 120
          # authSecretRef: bgp-auth-secret
          # ebgpMultihop: 10
          gracefulRestart:
            enabled: true
            restartTimeSeconds: 120
          families:
            - afi: ipv4
              safi: unicast
              advertisements:
                matchLabels:
                  advertise: "bgp"

      - apiVersion: cilium.io/v2alpha1
        kind: CiliumBGPClusterConfig
        metadata:
          name: bgp-peering
          namespace: kube-system
        spec:
          # nodeSelector:
          #   matchLabels:
          #     rack: rack0
          bgpInstances:
          - name: "instance-${var.bgp_asn}"
            localASN: ${var.bgp_asn}
            peers:
            - name: "peer-router"
              peerASN: ${var.bgp_asn}
              peerAddress: ${var.cluster_lan_gateway} # OPNSense IP
              peerConfigRef:
                name: "peer-config"
    EOF
  ]
}
