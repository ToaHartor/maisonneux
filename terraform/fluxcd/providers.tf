provider "helm" {
  kubernetes {
    config_path = "../../tmp/kubeconfig.yaml"
  }
}

provider "kubernetes" {
  config_path = "../../tmp/kubeconfig.yaml"
}
