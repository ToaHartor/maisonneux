# NB YOU CANNOT INSTALL MULTIPLE INSTANCES OF CERT-MANAGER IN A CLUSTER.
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager-csi-driver
# see https://github.com/cert-manager/csi-driver/tree/main/deploy/charts/csi-driver
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template
data "helm_template" "cert_manager_csi_driver" {
  namespace  = "cert-manager"
  name       = "cert-manager-csi-driver"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager-csi-driver"
  # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
  version      = "0.10.1"
  kube_version = var.kubernetes_version
  api_versions = []
}
