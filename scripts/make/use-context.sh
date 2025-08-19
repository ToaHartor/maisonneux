#!/bin/bash

set -euo pipefail

mkdir -p ~/.kube
mkdir -p ~/.talos

ENV=$1
TALOSCONFIG="tmp/talosconfig-${ENV}.yaml"

# Get cluster name from config outputs
CONTEXT=$(yq -r '.context' "$TALOSCONFIG")

# Merge talosctl config
yq -i "del(.contexts.${CONTEXT})" ~/.talos/config
talosctl config merge "$TALOSCONFIG"

# Merge kubectl config, talosctl can only use one node IP
NODES=$(yq -r ".contexts.${CONTEXT}.endpoints[0]" "$TALOSCONFIG")
talosctl kubeconfig -f -n "$NODES"

# Select target context for both CLI
kubectl config use-context "admin@$CONTEXT"
talosctl config context "$CONTEXT"