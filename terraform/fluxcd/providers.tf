provider "helm" {
  kubernetes = {
    config_path = "../../tmp/kubeconfig-${terraform.workspace}.yaml"
  }
}

provider "kubernetes" {
  config_path = "../../tmp/kubeconfig-${terraform.workspace}.yaml"
}
