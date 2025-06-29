#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE


# Get dependencies
source "scripts/utils/tf-utils.sh"

tfutils::get_folder_env "$1"

# If environment is recognized for fluxcd-$env, switch env to the right one and set TF folder and config file   
if [ "${TF_FOLDER}" == "fluxcd" ]; then \
    pushd "terraform/${TF_FOLDER}"
    tofu workspace select "${TF_DEPLOY_ENV}"
    popd
    # Set git remote domain for fluxcd
    # TODO : maybe do this only for TF_DEPLOY_ENV != production
    sed -i -E "s/flux_git_remote_domain(\s+)\=(\s+)\"(.*)\"/flux_git_remote_domain\1\=\2\"$(sh scripts/get_dev_machine_ip.sh)\"/" "terraform/${TF_FOLDER}/${TF_CONFIG_VARS_FILE}"
fi


cd "terraform/${TF_FOLDER}"
if [ "${TF_FOLDER}" == "k8s" ]; then
    # Only planning nodes
    pushd nodes
        tofu workspace select "${TF_DEPLOY_ENV}"
        tofu plan -out "${TF_FOLDER}.tfplan" -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars' 
    popd
else
    tofu plan -out "${TF_FOLDER}.tfplan" -var-file="${TF_CONFIG_VARS_FILE}" -var-file='../env/credentials.tfvars' 
fi