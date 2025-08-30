resource "ansible_playbook" "configure_bgp" {
  playbook   = "../../../ansible/opnsense/configure_bgp.yaml"
  name       = var.opnsense_host
  replayable = true

  extra_vars = {
    ansible_host     = var.opnsense_host
    api_key          = var.opnsense_api_key
    api_secret       = var.opnsense_api_secret
    opnsense_bgp_asn = local.opnsense_bgp_asn
    bgp_asn          = var.bgp_asn
    lb_network       = var.cluster_virtual_lb_pool
    lb_gateway       = var.cluster_lan_gateway
    node_list        = "${var.controllers}${length(var.workers) > 0 ? ",${var.workers}" : ""}"
  }
}
