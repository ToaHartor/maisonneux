#!/bin/bash

set -euo pipefail

# WE ASSUME THIS SCRIPT IS CALLED AT THE ROOT OF THE PROJECT
# The script exists until it becomes possible to upgrade Talos Linux with Terraform

function upgrade_node() {
    for node_ip in "$@"
    do
        CURRENT_TALOS_VERSION=$(talosctl version --nodes "$node_ip" | grep Tag | tail -n 1 | awk '{print $2}')

        schematic=$SCHEMATIC_ID
        # Check if node has nvidia drivers on it
        if talosctl get extensions --nodes "$node_ip" | grep -qc nvidia; then
            echo "Adding NVIDIA extensions to the upgrade"
            schematic=$SCHEMATIC_NVIDIA_ID
        fi

        # Still ask if same version, as we use upgrades to also update system extensions and kernel args

        if [[ $ACCEPT_ALL == 1 ]]; then 
            talosctl upgrade --nodes "$node_ip" \
                --image "factory.talos.dev/installer/$schematic:v$TALOS_VERSION"
        else
            read -p "Proceed to upgrade node $node_ip from version $CURRENT_TALOS_VERSION to version v$TALOS_VERSION ? (y/n): " -n 1 -r
            echo    # (optional) move to a new line
            if [[ $REPLY =~ ^[Yy]$ ]]
            then
                talosctl upgrade --nodes "$node_ip" \
                    --image "factory.talos.dev/installer/$schematic:v$TALOS_VERSION"
            fi
        fi
    done
}

# https://www.talos.dev/v1.9/talos-guides/upgrading-talos/

if [ $# -eq 0 ]; then
    echo "The cluster environment should be provided to the script."
    exit 1
fi

ENVIRONMENT=$1

# Ask for talos version
read -p "Please enter the Talos version to upgrade to (version/[q]uit): " INPUT_VERSION

case $INPUT_VERSION in
  "q" | "quit" | "")
    echo "Cancelling Talos upgrade."
    exit 0
    ;;
  *)
    TALOS_VERSION="$INPUT_VERSION"
esac


# https://www.talos.dev/v1.9/kubernetes-guides/upgrading-kubernetes/

# Get node ip list and retrieve control plane ip
make tf-output "k8s-${ENVIRONMENT}"

## Retrieve output dump in tmp/datavalue_k8s.json and get ips
CONTROLPLANE_IPS=$(jq -r '.controllers.value' tmp/datavalue_k8s.json)
WORKERS_IPS=$(jq -r '.workers.value' tmp/datavalue_k8s.json)

# Workers may be empty (e.g in staging)
if [ -z "$CONTROLPLANE_IPS" ]; then
    echo "Unable to get nodes ip addresses."
    exit 1
fi

# Transform IP lists strings into actual lists
IFS=',' read -r -a controlplanes <<< "$CONTROLPLANE_IPS"
IFS=',' read -r -a workers <<< "$WORKERS_IPS"

# Get installer image from Image Factory
SCHEMATIC_ID=$(curl -sS -X POST --data-binary @scripts/talos_schematic.yaml -H "Content-type: text/x-yaml" "https://factory.talos.dev/schematics" | jq -r '.id' -)

# shellcheck disable=SC2016
nvidia_schema=$(yq -r eval-all '. as $item ireduce ({}; . *+ $item)' scripts/talos_nvidia_extensions.yaml scripts/talos_schematic.yaml)
SCHEMATIC_NVIDIA_ID=$(curl -sS -X POST -H "Content-type: text/x-yaml" "https://factory.talos.dev/schematics"  --data-binary @- << EOF | jq -r '.id' -
$nvidia_schema
EOF
)

echo "Schematic ID retrieved from factory.talos.dev : $SCHEMATIC_ID"
echo "NVIDIA schematic ID retrieved from factory.talos.dev : $SCHEMATIC_NVIDIA_ID"

ACCEPT_ALL=0
read -p "Should we accept all upgrades ? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ACCEPT_ALL=1
fi

# Upgrade control planes first
upgrade_node "${controlplanes[@]}"

# Upgrade workers after, 
if [ -n "$WORKERS_IPS" ]; then
    upgrade_node "${workers[@]}"
fi