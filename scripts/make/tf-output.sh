#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

readarray -d '' FLUXCD_ENVS < <(find terraform/fluxcd/terraform.tfstate.d/* -type d -exec basename {} \;)
TF_FOLDER=$1

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
# If targetting k8s, we extract values only from nodes deployment
if [ "$1" = "k8s" ]; then
    pushd nodes
        tofu output -json >../../../tmp/datavalue_${TF_FOLDER}.json
    popd
else
    tofu output -json >../../tmp/datavalue_${TF_FOLDER}.json
fi
