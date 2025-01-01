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
    TF_CONFIG_VARS_FILE="config.${FLUXCD_ENV}.tfvars"
    pushd terraform/${TF_FOLDER}
    tofu workspace select ${FLUXCD_ENV}
    popd
    sed -i -E "s/flux_git_remote_domain(\s+)\=(\s+)\"(.*)\"/flux_git_remote_domain\1\=\2\"$(sh scripts/get_dev_machine_ip.sh)\"/" terraform/${TF_FOLDER}/${TF_CONFIG_VARS_FILE}
fi
cd terraform/${TF_FOLDER}
if [ "$1" = "k8s" ]; then
    # Only planning nodes
    pushd nodes
        tofu plan -out $1.tfplan -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars' 
    popd
else
    tofu plan -out $1.tfplan -var-file="${TF_CONFIG_VARS_FILE}" -var-file='../env/credentials.tfvars' 
fi