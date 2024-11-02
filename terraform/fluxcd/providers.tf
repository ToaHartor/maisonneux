provider "helm" {
  kubernetes {
    config_path = "../../tmp/kubeconfig.yml"
  }
}

provider "kubernetes" {
  config_path = "../../tmp/kubeconfig.yml"
}
