#!/bin/bash
set -euo pipefail

# THIS SCRIPT SHOULD ONLY BE USED WITH THE MAKEFILE


# Get dependencies
source "scripts/utils/tf-utils.sh"

tfutils::get_folder_env "$1"

TF_CONFIG_VARS=()

# If environment is recognized for fluxcd-$env, switch env to the right one and set TF folder and config file   
if [ "${TF_FOLDER}" == "fluxcd" ]; then \
    pushd "terraform/${TF_FOLDER}"
    tofu workspace select "${TF_DEPLOY_ENV}"
    popd
    # Add additional variables to terraform deployment
    # Get ips from ../k8s/config.env.tfvars
    traefik_ip=$(grep -Po "(?<=k8s_lb_traefik_ip\s?\=\s?\"?)[^\"\s]+" < "terraform/k8s/config.${TF_DEPLOY_ENV}.tfvars")
    otelcol_ip=$(grep -Po "(?<=k8s_lb_influxdb_ip\s?\=\s?\"?)[^\"\s]+" < "terraform/k8s/config.${TF_DEPLOY_ENV}.tfvars")
    baseport_number=$(grep -Po "(?<=opnsense_base_port_number\s?\=\s?)[^\s]+" < "terraform/k8s/config.${TF_DEPLOY_ENV}.tfvars")
    TF_CONFIG_VARS+=("-var=k8s_lb_traefik_ip=${traefik_ip}")
    TF_CONFIG_VARS+=("-var=k8s_lb_influxdb_ip=${otelcol_ip}")
    TF_CONFIG_VARS+=("-var=opnsense_base_port_number=${baseport_number}")
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
    tofu plan -out "${TF_FOLDER}.tfplan" -var-file="${TF_CONFIG_VARS_FILE}" -var-file='../env/credentials.tfvars' "${TF_CONFIG_VARS[@]}"
fi