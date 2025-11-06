#!/bin/bash

set -euo pipefail

# This script is used to perform the pre-flight check required by Cilium before doing the actual update.

if [ $# -ne 2 ]; then
  echo "Cilium version and cluster environment should be provided. Usage: cilium_preflight.sh <environment> <cilium_version>"
  exit 1
fi

ENVIRONMENT="$1"
CILIUM_VERSION="$2"

# Get terraform utility functions
source "./scripts/utils/tf-utils.sh"


function pre_flight_wait_confirm() {
  echo "Waiting for the chart to be up"
  sleep 15

  kubectl get daemonset -n kube-system | sed -n '1p;/cilium/p'

  kubectl get deployment -n kube-system cilium-pre-flight-check


  while IFS= read -n1 -r -p "Is the chart ready ? [y]es|[n]o : " && [[ $REPLY != "y" ]];
  do
    sleep 15

    kubectl get daemonset -n kube-system | sed -n '1p;/cilium/p'

    kubectl get deployment -n kube-system cilium-pre-flight-check
  done
}

# Set target context
mise run context "$ENVIRONMENT"


API_SERVER_PORT=$(jq '.outputs.kubeprism_port.value' "terraform/k8s/nodes/terraform.tfstate.d/${ENVIRONMENT}/terraform.tfstate")
# POD_CIDR=$(tfutils::get_tfvars_quoted_key "cluster_pod_cidr" "terraform/k8s/config.${ENVIRONMENT}.tfvars")

echo "Running the pre-flight test for the version ${CILIUM_VERSION}, described in https://docs.cilium.io/en/stable/operations/upgrade/#running-pre-flight-check-required"

# helm get values cilium --namespace=kube-system -o yaml > ./tmp/cilium-values.yaml
helm repo add cilium https://helm.cilium.io --force-update
helm repo update cilium

helm install cilium-preflight cilium/cilium --version "${CILIUM_VERSION}" \
  --namespace=kube-system \
  --set preflight.enabled=true \
  --set agent=false \
  --set operator.enabled=false \
  --set envoy.enabled=false \
  --set "k8sServiceHost=localhost" \
  --set "k8sServicePort=$API_SERVER_PORT"

# Waiting for the user to check if the deployment and daemonset are ready based on kubectl output.
# Manual check is required.
pre_flight_wait_confirm

echo "Deleting the pre-flight release"

helm delete cilium-preflight --namespace=kube-system

echo "Last step : update Cilium version in k8s terraform and apply the terraform"