#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

readarray -d '' FLUXCD_ENVS < <(find terraform/fluxcd/terraform.tfstate.d/* -type d -exec basename {} \;)
TF_FOLDER=$1
TF_CONFIG_VARS_FILE="config.tfvars"

FLUXCD_ENV=$(printf "%s\n" "${FLUXCD_ENVS[@]}" | sed -n "/${1#fluxcd-*}/p")

# If environment is recognized for fluxcd-$env, switch env to the right one and set TF folder and config file
if [ "${FLUXCD_ENV}" != "" ]; then \
    # Env in this TF folder
    TF_FOLDER="fluxcd"
    pushd terraform/${TF_FOLDER}
    tofu workspace select ${FLUXCD_ENV}
    popd
fi
cd terraform/${TF_FOLDER}
# Apply modules separately to first deploy nodes then resources in k8s, as providers are necessarily initialized on the first step
if [ "$1" = "k8s" ]; then
    echo "Creating nodes..."
    pushd nodes
        tofu apply $1.tfplan;
        tofu output -raw talosconfig >../../../tmp/talosconfig.yaml
        tofu output -raw kubeconfig >../../../tmp/kubeconfig.yaml
        tofu output -raw proxmox_csi_account >../../../tmp/proxmoxcsi.yaml
        CONTROLLER_NODES=$(tofu output -raw controllers)
        WORKER_NODES=$(tofu output -raw workers)
        KUBEPRISM_PORT=$(tofu output -raw kubeprism_port)
    popd
    # echo "Waiting until Kubernetes API is up"
    # KUBE_API=$(yq -r '.clusters[0].cluster.server' ../../tmp/kubeconfig.yaml)
    # # Write kube ca in tmp dir
    # yq -r '.clusters[0].cluster.certificate-authority-data' ../../tmp/kubeconfig.yaml | base64 -d > ../../tmp/kube-ca.crt

    # curl -sS --retry 100 --retry-all-errors --connect-timeout 1 --cacert ../../tmp/kube-ca.crt $KUBE_API/version

    echo "Applying helm charts..."
    pushd charts
        tofu plan -out $1.tfplan -var="kubeprism_port=$KUBEPRISM_PORT" -var="controllers=$CONTROLLER_NODES" -var="workers=$WORKER_NODES" -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars'
        tofu apply $1.tfplan;
    popd
else
    tofu apply $1.tfplan;
fi