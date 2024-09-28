locals {
  # Values from https://github.com/yandex-cloud/k8s-csi-s3/tree/master/deploy/helm/csi-s3
  s3_csi_values = {
    storageClass = {
      create        = true
      name          = "csi-s3"
      singleBucket  = true
      mounter       = "geesefs"
      reclaimPolicy = "Delete"
      # annotations = ""
    }
    secret = {
      create    = true
      name      = "csi-s3-secret"
      accessKey = var.minio_access_key
      secretKey = var.minio_secret_key
      endpoint  = "http://${var.truenas_vm_host}:${var.minio_port}"
      # region = ""
    }
  }
}


# see https://github.com/yandex-cloud/k8s-csi-s3/releases
data "helm_template" "csi_s3" {
  namespace    = "kube-system" # "democratic-csi"
  name         = "csi-s3"
  repository   = "https://yandex-cloud.github.io/k8s-csi-s3/charts"
  chart        = "csi-s3"
  version      = "0.41.1"
  kube_version = var.kubernetes_version
  api_versions = []
  values       = [yamlencode(local.s3_csi_values)]
}
