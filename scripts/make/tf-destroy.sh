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
fi
cd terraform/${TF_FOLDER}
# Destroying both folders in k8s
if [ "$1" = "k8s" ]; then
    pushd nodes
        echo "Destroying cluster..."
        tofu apply -destroy -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars'
    popd
    pushd charts
        echo "Removing tfstate in charts folder"
        rm terraform.tfstate*
    popd
else
    tofu apply -destroy -var-file="${TF_CONFIG_VARS_FILE}" -var-file='../env/credentials.tfvars'
fi