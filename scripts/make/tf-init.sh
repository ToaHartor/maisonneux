#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE

# Get dependencies
source "./scripts/utils/tf-utils.sh"

tfutils::get_folder_env "$1"

cd "terraform/${TF_FOLDER}"

if [ "${TF_FOLDER}" == "k8s" ]; then
    pushd charts
        tofu init -lockfile=readonly
    popd
    pushd nodes
        tofu init -lockfile=readonly
    popd
else
    tofu init -lockfile=readonly
fi