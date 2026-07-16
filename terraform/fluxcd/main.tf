terraform {
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = "3.2.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
  }
}

locals {

  // ${var.flux_git_remote_protocol}://
  // Protocol is already included otherwise it does not pass schema validation
  flux_git_source_url = "${var.flux_git_remote_protocol}://${var.flux_git_remote_domain}:${var.flux_git_remote_port}/${var.flux_git_repository}.git"

  ingress_ports = {
    web       = var.opnsense_base_port_number + 80
    websecure = var.opnsense_base_port_number + 443
    ssh       = var.opnsense_base_port_number + 22
  }

  general_config = merge({
    "environment" = terraform.workspace
    # cilium config
    "control_plane_endpoints" = join(" ", [for ip in split(",", var.controller_nodes) : "https://${ip}:6443"])
    "cluster_pod_cidr"        = var.cluster_pod_cidr
    # s3 stuff
    "minio_url"             = var.minio_access_url
    "minio_backup_bucket"   = var.minio_backup_bucket
    "garage_admin_endpoint" = var.garage_storage_cluster_api_address
    "garage_gateway_lb_ip"  = var.k8s_lb_garage_gateway_ip
    "garage_bootstrap_node" = var.garage_bootstrap_node
    # certificate stuff
    "acme_server_url" = var.use_letsencrypt_production_server ? "https://acme-v02.api.letsencrypt.org/directory" : "https://acme-staging-v02.api.letsencrypt.org/directory"
    "main_domain"     = var.main_domain
    "second_domain"   = var.second_domain
    "auth_subdomain"  = "auth"
    # postgres stuff
    "psql_suffix"             = var.cnpg_recovery ? "-temp" : ""
    "psql_database_namespace" = "postgres"
    "psql_cluster_name"       = "psql-cluster"
    # other stuff
    "gpu_runtime_class"         = var.use_nvidia_gpu ? "nvidia" : "null"
    "fastdata_storage"          = var.storage.fastdata
    "git_repo_url"              = local.flux_git_source_url
    "git_branch"                = var.flux_git_branch
    "nfs_server"                = var.truenas_vm_host
    "patch_dns"                 = !var.is_internet_ingress # Patch only when it's not an ingress
    "local_dns_server"          = var.is_internet_ingress ? "" : var.local_dns_server
    "opnsense_exposed_ip"       = var.opnsense_exposed_ip
    "traefik_lb_ip"             = var.k8s_lb_traefik_ip
    "traefik_web_lb_port"       = local.ingress_ports.web
    "traefik_websecure_lb_port" = local.ingress_ports.websecure
    "traefik_ssh_lb_port"       = local.ingress_ports.ssh
    "influxdb_lb_ip"            = var.k8s_lb_influxdb_ip
    "legacy_vm_ip"              = var.legacy_vm_ip
    },
    { for k, v in local.ingress_ports : "main_domain_${k}" => join("", [var.main_domain, (var.is_internet_ingress ? "" : ":${v}")]) },
    var.second_domain != "" ? { for k, v in local.ingress_ports : "second_domain_${k}" => join("", [var.second_domain, (var.is_internet_ingress ? "" : ":${v}")]) } : {},
    { for k, v in var.truenas_nfs_paths : "nfs_path_${k}" => v },
  )

  # flux2 values : https://artifacthub.io/packages/helm/fluxcd-community/flux2?modal=values
  # flux-sync https://artifacthub.io/packages/helm/fluxcd-community/flux2-sync?modal=values
  # flux_sync_helm_values = {
  #   gitRepository = {
  #     spec = {
  #       url = "${var.flux_git_remote_protocol}://${var.flux_git_remote_domain}:${var.flux_git_remote_port}/${var.flux_git_repository}.git"
  #       secretRef = {
  #         name = "flux-git-credentials"
  #       }
  #       ref = {
  #         branch = var.flux_git_branch
  #       }
  #       interval = "1m"
  #       ignore   = <<-EOF
  #       # Ignore all folders, but include the ones with cluster resources
  #       /*
  #       # Cluster folders include
  #       !/kubernetes/clusters/${terraform.workspace}
  #       !/kubernetes/apps/
  #       !/kubernetes/core/
  #       !/kubernetes/common/
  #       !/kubernetes/platform/
  #       !/kubernetes/system/
  #       # Include helm charts folder as well
  #       !/helm/
  #       # Remove flux-system as well
  #       kubernetes/clusters/**/flux-system/"
  #       EOF
  #     }
  #   }
  #   kustomization = {
  #     spec = {
  #       prune = true
  #       force = true
  #       path  = "./kubernetes/clusters/${terraform.workspace}"
  #     }
  #   }
  # }
  # fluxcd_helm_values = {
  #   // Increase concurrent reconciliations for fluxcd controllers
  #   kustomizeController = {
  #     priorityClassName = "system-cluster-critical"
  #     container = {
  #       additionalArgs = ["--concurrent=15", "--concurrent-ssa=15"]
  #     }
  #   }
  #   helmController = {
  #     priorityClassName = "system-cluster-critical"
  #     container = {
  #       additionalArgs = ["--concurrent=15"]
  #     }
  #   }
  #   imageAutomationController = {
  #     priorityClassName = "system-cluster-critical"
  #   }
  #   imageReflectionController = {
  #     priorityClassName = "system-cluster-critical"
  #   }
  #   notificationController = {
  #     priorityClassName = "system-cluster-critical"
  #   }
  #   sourceController = {
  #     priorityClassName = "system-cluster-critical"
  #     extraEnv = [
  #       // Mount sigstore to tmp to verify cosign signatures for OCIRepositories
  #       {
  #         name  = "TUF_ROOT"
  #         value = "/tmp/.sigstore"
  #       }
  #     ]
  #   }
  # }
}

# example from https://github.com/fluxcd/terraform-provider-flux/blob/main/examples/helm-install/main.tf
# resource "helm_release" "fluxcd" {
#   repository      = "https://fluxcd-community.github.io/helm-charts"
#   chart           = "flux2"
#   version         = "2.18.4"
#   name            = "flux2"
#   namespace       = "flux-system"
#   upgrade_install = true
#   values          = [yamlencode(local.fluxcd_helm_values)]

#   depends_on = [kubernetes_secret_v1.flux_git_credentials]
# }

# resource "helm_release" "fluxcd_sync" {
#   repository = "https://fluxcd-community.github.io/helm-charts"
#   chart      = "flux2-sync"
#   version    = "1.14.6"

#   # Note: Do not change the name or namespace of this resource. The below mimics the behaviour of "flux bootstrap".
#   name            = "flux-system"
#   namespace       = "flux-system"
#   upgrade_install = true

#   values     = [yamlencode(local.flux_sync_helm_values)]
#   depends_on = [helm_release.fluxcd]
# }

// https://registry.terraform.io/modules/controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes/latest
// https://github.com/controlplaneio-fluxcd/terraform-kubernetes-flux-operator-bootstrap/tree/main#inputs
module "flux_operator_bootstrap" {
  source  = "controlplaneio-fluxcd/flux-operator-bootstrap/kubernetes"
  version = "0.8.0"

  # depends_on = [kubernetes_secret_v1.flux_git_credentials]

  # Increment this revision if you need to force a re-bootstrap
  revision = var.fluxcd_bootstrap_revision

  gitops_resources = {
    instance_yaml = file("../../kubernetes/clusters/${terraform.workspace}/flux-system/flux-instance.yaml")
    operator_chart = {
      values_yaml = file("../../kubernetes/clusters/${terraform.workspace}/flux-system/flux-operator-values.yaml")
    }
  }

  managed_resources = {
    secrets_yaml = <<-YAML
      apiVersion: v1
      kind: Secret
      metadata:
        name: flux-git-credentials
      type: Opaque
      stringData:
        username: '${var.flux_git_user}'
        password: '${var.flux_git_token}'
        identity: '${var.flux_git_ssh_config != null ? var.flux_git_ssh_config.private_key : ""}'
        identity.pub: '${var.flux_git_ssh_config != null ? var.flux_git_ssh_config.public_key : ""}'
        known_hosts: '${var.flux_git_ssh_config != null ? var.flux_git_ssh_config.known_hosts : ""}'
    YAML
    runtime_info = {
      labels = {
        "reconcile.fluxcd.io/watch" = "Enabled"
      }
      data = {
        source_repo_url               = local.flux_git_source_url
        source_repo_branch            = var.flux_git_branch
        source_repo_cluster_directory = "/kubernetes/clusters/${terraform.workspace}"
      }
    }
  }

  job = {
    tolerations = [{
      key      = "node-role.kubernetes.io/control-plane"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
  }
}
