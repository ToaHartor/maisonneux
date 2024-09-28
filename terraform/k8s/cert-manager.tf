locals {
  cert_manager_ingress_ca_manifests = [
    # see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.ClusterIssuer
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "selfsigned-issuer"
      }
      spec = {
        selfSigned = {}
      }
    },
    # see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.Certificate
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = "selfsigned-ca"
        namespace = "cert-manager"
      }
      spec = {
        isCA = true
        subject = {
          # organizations = [
          #   var.ingress_domain,
          # ]
          organizationalUnits = [
            "Kubernetes",
          ]
        }
        commonName = "Kubernetes Ingress"
        privateKey = {
          algorithm = "ECDSA" # NB Ed25519 is not yet supported by chrome 93 or firefox 91.
          size      = 256
        }
        duration   = "4320h" # NB 4320h (180 days). default is 2160h (90 days).
        secretName = "selfsigned-ca"
        issuerRef = {
          name  = "selfsigned-issuer"
          kind  = "ClusterIssuer"
          group = "cert-manager.io"
        }
      }
    },
    # see https://cert-manager.io/docs/reference/api-docs/#cert-manager.io/v1.ClusterIssuer
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "root-ca-issuer"
      }
      spec = {
        ca = {
          secretName = "selfsigned-ca"
        }
      }
    },
  ]
  cert_manager_ingress_ca_manifest = join("---\n", [for d in local.cert_manager_ingress_ca_manifests : yamlencode(d)])

  cert_manager_values = {
    crds = {
      # NB installCRDs is generally not recommended, BUT since this
      #    is a development cluster we YOLO it.
      enabled = true
      keep    = true
    }
    livenessProbe = {
      enabled = true
    }
    # prometheus = {
    #   enabled = true
    # }
  }
}

# NB YOU CANNOT INSTALL MULTIPLE INSTANCES OF CERT-MANAGER IN A CLUSTER.
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
# see https://cert-manager.io/docs/configuration/selfsigned/#bootstrapping-ca-issuers
# see https://cert-manager.io/docs/usage/ingress/
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template
data "helm_template" "cert_manager" {
  namespace  = "cert-manager"
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
  version      = "1.15.3"
  kube_version = var.kubernetes_version
  api_versions = []
  values       = [yamlencode(local.cert_manager_values)]
}
