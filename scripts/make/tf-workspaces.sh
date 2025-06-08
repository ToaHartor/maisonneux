#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

WS=(production staging)

function create_workspaces() {
  for i in "${WS[@]}"
  do
    tofu workspace new "$i" || true
  done
}


# Create k8s workspaces
pushd terraform/k8s/nodes
create_workspaces
popd

# Create fluxcd workspaces
pushd terraform/fluxcd
create_workspaces
popd