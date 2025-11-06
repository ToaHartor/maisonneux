#!/bin/bash

set -euo pipefail

# WE ASSUME THIS SCRIPT IS CALLED AT THE ROOT OF THE PROJECT
# The script exists until it becomes possible to upgrade K8S on Talos Linux with Terraform

if [ $# -eq 0 ]; then
    echo "The cluster environment should be provided to the script."
    exit 1
fi

ENVIRONMENT=$1

# Get cluster k8s version
CURRENT_K8S_VERSION=$(kubectl version -o json | jq -r '.serverVersion.gitVersion' | tr -d "v")

# Ask for k8s version
read -p "Please enter the Kubernetes version to upgrade to (current is ${CURRENT_K8S_VERSION}) (version/[q]uit): " INPUT_VERSION

case $INPUT_VERSION in
  "q" | "quit" | "")
    echo "Cancelling Kubernetes upgrade."
    exit 0
    ;;
  *)
    K8S_VERSION="$INPUT_VERSION"
esac

# https://www.talos.dev/v1.9/kubernetes-guides/upgrading-kubernetes/

# Get node ip list and retrieve control plane ip
mise run terraform output "k8s-${ENVIRONMENT}"

## Retrieve output dump in tmp/datavalue_k8s.json and get ip
CONTROLPLANE_IPS=$(jq -r '.controllers.value' tmp/datavalue_k8s.json)
IFS=',' read -r -a controlplanes <<< "$CONTROLPLANE_IPS"
CONTROLPLANE_IP=${controlplanes[0]} # Take the first IP in the array

if [ -z $CONTROLPLANE_IP ]; then
    echo "Unable to get control plane ip address."
    exit 1
fi

echo "Targetting control plane node $CONTROLPLANE_IP"

# Display dry run and wait for confirmation

talosctl --nodes "$CONTROLPLANE_IP" upgrade-k8s --to "$K8S_VERSION" --dry-run

read -p "Are you sure you want to upgrade k8s version to $K8S_VERSION ? ([y]es/[n]o): " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Run k8s upgrade
    echo "Upgrading nodes..."
    talosctl --nodes "$CONTROLPLANE_IP" upgrade-k8s --to "$K8S_VERSION"
fi