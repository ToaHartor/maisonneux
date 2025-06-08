#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

# Get dependencies
source "scripts/utils/tf-utils.sh"

tfutils::get_folder_env "$1"

# If environment is recognized for fluxcd-$env, switch env to the right one and set TF folder and config file
if [ "${TF_FOLDER}" == "fluxcd" ]; then \
    # Env in this TF folder
    pushd "terraform/${TF_FOLDER}"
    tofu workspace select "${TF_DEPLOY_ENV}"
    popd
fi
cd "terraform/${TF_FOLDER}"
# If targetting k8s, we extract values only from nodes deployment
if [ "${TF_FOLDER}" == "k8s" ]; then
    pushd nodes
        tofu workspace select "${TF_DEPLOY_ENV}"
        tofu output -json >"../../../tmp/datavalue_${TF_FOLDER}.json"
    popd
else
    tofu output -json >"../../tmp/datavalue_${TF_FOLDER}.json"
fi
