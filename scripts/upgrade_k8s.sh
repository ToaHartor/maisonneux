#!/bin/bash

set -euo pipefail

# WE ASSUME THIS SCRIPT IS CALLED AT THE ROOT OF THE PROJECT
# The script exists until it becomes possible to upgrade K8S on Talos Linux with Terraform

export TALOSCONFIG=tmp/talosconfig.yaml

if [ $# -eq 0 ]; then
    echo "The version k8s should be upgraded to must be provided."
    exit 1
fi

K8S_VERSION=$1

# https://www.talos.dev/v1.9/kubernetes-guides/upgrading-kubernetes/

# Get node ip list and retrieve control plane ip
make tf-output k8s

## Retrieve output dump in tmp/datavalue_k8s.json and get ip
CONTROLPLANE_IPS=$(jq -r '.controllers.value' tmp/datavalue_k8s.json)
IFS=',' read -r -a controlplanes <<< "$CONTROLPLANE_IPS"
CONTROLPLANE_IP=$controlplanes # Take the first IP in the array

if [ -z $CONTROLPLANE_IP ]; then
    echo "Unable to get control plane ip address."
    exit 1
fi

echo "Targetting control plane node $CONTROLPLANE_IP"

# Display dry run and wait for confirmation

talosctl --nodes $CONTROLPLANE_IP upgrade-k8s --to $K8S_VERSION --dry-run

read -p "Are you sure you want to upgrade k8s version to $K8S_VERSION ? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Run k8s upgrade
    echo "Upgrading nodes..."
    talosctl --nodes $CONTROLPLANE_IP upgrade-k8s --to $K8S_VERSION

fi