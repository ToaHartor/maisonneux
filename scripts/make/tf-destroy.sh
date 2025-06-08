#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

# Get dependencies
source "./scripts/utils/tf-utils.sh"

tfutils::get_folder_env "$1"

# If environment is recognized for fluxcd-$env, switch env to the right one and set TF folder and config file
if [ "${TF_FOLDER}" == "fluxcd" ]; then \
    pushd "terraform/${TF_FOLDER}"
    tofu workspace select "${TF_DEPLOY_ENV}"
    popd
fi
cd "terraform/${TF_FOLDER}"
# Destroying both folders in k8s
if [ "${TF_FOLDER}" == "k8s" ]; then
    pushd nodes
        echo "Destroying cluster..."
        tofu workspace select "${TF_DEPLOY_ENV}"
        tofu apply -destroy -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars'
    popd
    pushd charts
        echo "Removing tfstate in charts folder"
        rm terraform.tfstate*
    popd
else
    tofu apply -destroy -var-file="${TF_CONFIG_VARS_FILE}" -var-file='../env/credentials.tfvars'
fi