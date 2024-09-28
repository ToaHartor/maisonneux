locals {
  # Helm values, based on https://github.com/democratic-csi/charts/blob/master/stable/democratic-csi/values.yaml
  # See https://github.com/democratic-csi/charts/blob/master/stable/democratic-csi/examples/freenas-iscsi.yaml for values dedicated for TrueNAS iSCSI driver

  democratic_csi_iscsi_values = {
    csiDriver = {
      name = "org.democratic-csi.iscsi"
    }
    storageClasses = [
      {
        name                 = "truenas-iscsi-csi"
        defaultClass         = false
        reclaimPolicy        = "Delete"    # Reclaim
        volumeBindingMode    = "Immediate" # WaitForFirstConsumer
        allowVolumeExpansion = true
        parameters = {
          fsType = "ext4"
        }
        mountOptions = []
        # secrets = {
        #   # TODO : secrets from TrueNAS iSCSI share
        # }
      }
    ]
    # volumeSnapshotClasses = []
    # Node values required for Talos Linux with iSCSI come from https://github.com/democratic-csi/democratic-csi?tab=readme-ov-file#patch-nodes
    node = {
      hostPID = true
      driver = {
        extraEnv = [
          {
            name  = "ISCSIADM_HOST_STRATEGY"
            value = "nsenter"
          },
          {
            name  = "ISCSIADM_HOST_STRATEGY"
            value = "/usr/local/sbin/iscsiadm"
          }
        ]
        iscsiDirHostPath     = "/usr/local/etc/iscsi"
        iscsiDirHostPathType = "" # Directory
      }
    }
    driver = {
      config = {
        # Driver config values from here https://github.com/democratic-csi/democratic-csi/blob/master/examples/freenas-api-iscsi.yaml
        driver = "freenas-api-iscsi"
        # instance_id = ""
        httpConnection = {
          protocol      = "http"
          host          = var.truenas_vm_host
          port          = var.truenas_vm_port
          apiKey        = var.truenas_vm_apikey
          allowInsecure = true
          apiVersion    = 2
        }
        zfs = {
          # cli = {
          #   sudoEnabled = true
          # }

          datasetParentName = "data-mirror/k8s"
          # Leave empty to disable it
          detachedSnapshotsDatasetParentName = ""
          zvolCompression                    = ""
          zvolDedup                          = ""
          zvolEnableReservation              = false
          # zvolBlocksize = "16K"
        }
        iscsi = {
          # Should be configured beforehand in Share > iSCSI in TrueNAS
          targetPortal  = "${var.truenas_vm_host}:3260"
          targetPortals = []
          interface     = ""
          namePrefix    = "csi-"
          nameSuffix    = "k8s"
          targetGroups = [
            {
              targetGroupPortalGroup    = 1
              targetGroupInitiatorGroup = 3
              # None, CHAP, or CHAP Mutual
              targetGroupAuthType = "None"
            }
          ]
          # Following depends on which settings were set up in iSCSI share
          extentInsecureTpc              = true
          extentXenCompat                = false
          extentDisablePhysicalBlocksize = true
          # 512, 1024, 2048, or 4096,
          extentBlocksize = 512
          # "" (let FreeNAS decide, currently defaults to SSD), Unknown, SSD, 5400, 7200, 10000, 15000
          extentRpm = "SSD"
          # 0-100 (0 == ignore)
          extentAvailThreshold = 0
        }
      }
    }
  }

  # Helm values, based on https://github.com/democratic-csi/charts/blob/master/stable/democratic-csi/values.yaml
  # See https://github.com/democratic-csi/charts/blob/master/stable/democratic-csi/examples/freenas-nfs.yaml for values dedicated for TrueNAS NFS driver
  democratic_csi_nfs_values = {
    csiDriver = {
      name          = "org.democratic-csi.nfs"
      fsGroupPolicy = "File"
    }
    storageClasses = [
      {
        name                 = "truenas-nfs-csi"
        defaultClass         = false
        reclaimPolicy        = "Delete" # Reclaim
        volumeBindingMode    = "Immediate"
        allowVolumeExpansion = true
        parameters = {
          fsType = "nfs"
        }
        mountOptions = ["noatime", "nfsvers=4.2"]
        secrets = {
          # TODO : secrets from TrueNAS iSCSI share
        }
      }
    ]
    volumeSnapshotClasses = []
    driver = {
      config = {
        # Config values from https://github.com/democratic-csi/democratic-csi/blob/master/examples/freenas-api-nfs.yaml
        driver = "freenas-api-nfs"
      }
    }
  }
}



# see https://github.com/democratic-csi/charts
# requires a privileged namespace (here we will use kube-system)
# it also requires one helm deployment per type of csi storage (here one deployment for truenas iscsi and one for truenas nfs)
data "helm_template" "democratic_csi_truenas_iscsi" {
  namespace    = "kube-system" # "democratic-csi"
  name         = "democratic-csi-truenas-iscsi"
  repository   = "https://democratic-csi.github.io/charts"
  chart        = "democratic-csi"
  version      = "0.14.6"
  kube_version = var.kubernetes_version
  api_versions = []
  values       = [yamlencode(local.democratic_csi_iscsi_values)]
}


# data "helm_template" "democratic_csi_truenas_nfs" {
#   namespace    = "kube-system" # "democratic-csi"
#   name         = "democratic-csi-truenas-nfs"
#   repository   = "https://democratic-csi.github.io/charts"
#   chart        = "democratic-csi"
#   version      = "0.14.6"
#   kube_version = var.kubernetes_version
#   api_versions = []
#   values       = [yamlencode(local.democratic_csi_nfs_values)]
# }
