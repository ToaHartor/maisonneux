// see https://www.talos.dev/v1.7/kubernetes-guides/network/deploying-cilium/#method-4-helm-manifests-inline-install
// see https://github.com/cilium/cilium/releases
// see https://github.com/cilium/cilium/tree/v1.16.0/install/kubernetes/cilium
resource "helm_release" "cilium" {
  depends_on = [data.http.wait_k8sapi]
  namespace  = "kube-system"
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.18.1"
  # values     = [local.cilium_values]
  values = [file("./cilium_values.yaml")]
  wait   = false # Do not wait for resources as the chart is designed like this
  set = [{
    name  = "k8sServicePort"
    value = var.kubeprism_port
    },
    {
      name  = "ipv4NativeRoutingCIDR"
      value = var.cluster_pod_cidr
    }
  ]
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
  worker_nodes        = var.workers != "" ? split(",", var.workers) : []
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
      - apiVersion: cilium.io/v2
        kind: "CiliumLoadBalancerIPPool"
        metadata:
          name: "external"
        spec:
          blocks:
            - cidr: ${var.cluster_virtual_lb_pool}
      - apiVersion: cilium.io/v2
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

      - apiVersion: cilium.io/v2
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

      - apiVersion: cilium.io/v2
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
              peerASN: ${local.opnsense_bgp_asn} # OPNSense BGP ASN
              peerAddress: ${var.cluster_lan_gateway} # OPNSense IP
              peerConfigRef:
                name: "peer-config"
    EOF
  ]
}
