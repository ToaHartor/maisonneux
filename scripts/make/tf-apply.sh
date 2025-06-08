#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

# Get dependencies
source "./scripts/utils/tf-utils.sh"

tfutils::get_folder_env "$1"

# If environment is recognized for fluxcd-$env, switch env to the right one and set TF folder and config file
# For k8s terraform environment, we do this in the if right after 
if [ "${TF_FOLDER}" == "fluxcd" ]; then \
    # Env in this TF folder
    pushd "terraform/${TF_FOLDER}"
    tofu workspace select "${TF_DEPLOY_ENV}"
    popd
fi
cd "terraform/${TF_FOLDER}"
# Apply modules separately to first deploy nodes then resources in k8s, as providers are necessarily initialized on the first step
if [ "${TF_FOLDER}" == "k8s" ]; then
    echo "Creating nodes..."
    pushd nodes
        tofu workspace select "${TF_DEPLOY_ENV}"
        tofu apply "${TF_FOLDER}.tfplan"
        tofu output -raw talosconfig >"../../../tmp/talosconfig-${TF_DEPLOY_ENV}.yaml"
        tofu output -raw kubeconfig >"../../../tmp/kubeconfig-${TF_DEPLOY_ENV}.yaml"
        # tofu output -raw proxmox_csi_account >../../../tmp/proxmoxcsi.yaml
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
        tofu plan -out "${TF_FOLDER}.tfplan" -var="deploy_env=${TF_DEPLOY_ENV}" -var="kubeprism_port=$KUBEPRISM_PORT" -var="controllers=$CONTROLLER_NODES" -var="workers=$WORKER_NODES" -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars'
        tofu apply "${TF_FOLDER}.tfplan";
    popd
else
    tofu apply "${TF_FOLDER}.tfplan";
fi