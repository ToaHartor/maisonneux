#!/bin/bash

set -euo pipefail

# WE ASSUME THIS SCRIPT IS CALLED AT THE ROOT OF THE PROJECT
# The script exists until it becomes possible to upgrade Talos Linux with Terraform

export TALOSCONFIG=tmp/talosconfig.yaml


function upgrade_node() {
    for node_ip in "$@"
    do
        if [[ $ACCEPT_ALL == 1 ]]; then 
            talosctl upgrade --nodes $node_ip \
                --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION
        else
            read -p "Proceed to upgrade node $node_ip from version $(talosctl version --nodes $node_ip | grep Tag | tail -n 1 | awk '{print $2}') to version v$TALOS_VERSION ? " -n 1 -r
            echo    # (optional) move to a new line
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
                talosctl upgrade --nodes $node_ip \
                    --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION
            fi
        fi
    done
}

# https://www.talos.dev/v1.9/talos-guides/upgrading-talos/

if [ $# -eq 0 ]; then
    echo "The version Talos Linux should be upgraded to must be provided."
    exit 1
fi

TALOS_VERSION=$1
ACCEPT_ALL=0
if [ $# -ge 2 ]; then
    ACCEPT_ALL=$([[ "$2" == "-y" ]] || [[ "$2" == "--yes" ]] && echo 1 || echo 0)
fi

# https://www.talos.dev/v1.9/kubernetes-guides/upgrading-kubernetes/

# Get node ip list and retrieve control plane ip
make tf-output k8s

## Retrieve output dump in tmp/datavalue_k8s.json and get ips
CONTROLPLANE_IPS=$(jq -r '.controllers.value' tmp/datavalue_k8s.json)
WORKERS_IPS=$(jq -r '.workers.value' tmp/datavalue_k8s.json)


if [ -z $CONTROLPLANE_IPS ] || [ -z $WORKERS_IPS ]; then
    echo "Unable to get nodes ip addresses."
    exit 1
fi

# Transform IP lists strings into actual lists
IFS=',' read -r -a controlplanes <<< "$CONTROLPLANE_IPS"
IFS=',' read -r -a workers <<< "$WORKERS_IPS"

# Get installer image from Image Factory
SCHEMATIC_ID=$(curl -sS -X POST --data-binary @scripts/talos_schematic.yaml -H "Content-type: text/x-yaml" "https://factory.talos.dev/schematics" | jq -r '.id' -)

echo "Schematic ID retrieved from factory.talos.dev : $SCHEMATIC_ID"

# Upgrade control planes first
upgrade_node "${controlplanes[@]}"

# Upgrade workers then
upgrade_node "${workers[@]}"