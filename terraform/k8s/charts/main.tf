terraform {
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/helm
    # see https://github.com/hashicorp/terraform-provider-helm
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    # see https://registry.terraform.io/providers/siderolabs/talos
    # see https://github.com/siderolabs/terraform-provider-talos
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }

    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

locals {
  kubeconfig_path = "../../../tmp/kubeconfig-${var.deploy_env}.yaml"
  kubeconfig_raw  = yamldecode(file(local.kubeconfig_path))
  talosconfig_raw = yamldecode(file("../../../tmp/talosconfig-${var.deploy_env}.yaml"))

  opnsense_bgp_asn  = 64555
  control_plane_ips = split(",", var.controllers)


  talosconfig = {
    ca            = local.talosconfig_raw.contexts[var.cluster_name].ca
    crt           = local.talosconfig_raw.contexts[var.cluster_name].crt
    key           = local.talosconfig_raw.contexts[var.cluster_name].key
    controlplanes = local.talosconfig_raw.contexts[var.cluster_name].endpoints
  }

  kubeconfig = {
    api_endpoint      = local.kubeconfig_raw.clusters[0].cluster.server
    client_cert_bytes = local.kubeconfig_raw.users[0].user.client-certificate-data
    client_key_bytes  = local.kubeconfig_raw.users[0].user.client-key-data
    cluster_ca_bytes  = local.kubeconfig_raw.clusters[0].cluster.certificate-authority-data
  }
}

provider "helm" {
  kubernetes = {
    config_path = local.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

data "http" "wait_k8sapi" {
  url                = "${local.kubeconfig.api_endpoint}/version"
  ca_cert_pem        = base64decode(local.kubeconfig.cluster_ca_bytes)
  method             = "GET"
  request_timeout_ms = 1000
  retry {
    min_delay_ms = 1000
    max_delay_ms = 1000
    attempts     = 100
  }
}
