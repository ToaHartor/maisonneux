// Outputs from module k8s

output "talosconfig" {
  value     = (terraform.workspace == "k8s") ? module.k8scluster[0].talosconfig : ""
  sensitive = true
}

output "kubeconfig" {
  value     = (terraform.workspace == "k8s") ? module.k8scluster[0].kubeconfig : ""
  sensitive = true
}

output "controllers" {
  value = (terraform.workspace == "k8s") ? module.k8scluster[0].controllers : ""
}

output "workers" {
  value = (terraform.workspace == "k8s") ? module.k8scluster[0].workers : ""
}
