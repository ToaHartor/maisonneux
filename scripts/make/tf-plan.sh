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
    tfvars_file="terraform/k8s/config.${TF_DEPLOY_ENV}.tfvars"
    # TODO : get input variables from tfstate instead ?
    traefik_ip=$(tfutils::get_tfvars_quoted_key "k8s_lb_traefik_ip" "$tfvars_file")
    otelcol_ip=$(tfutils::get_tfvars_quoted_key "k8s_lb_influxdb_ip" "$tfvars_file")
    baseport_number=$(tfutils::get_tfvars_number_key "opnsense_base_port_number" "$tfvars_file")
    use_nvidia_gpu=$(tfutils::get_tfvars_boolean_key "use_nvidia_gpu" "$tfvars_file")
    TF_CONFIG_VARS+=("-var=k8s_lb_traefik_ip=${traefik_ip}")
    TF_CONFIG_VARS+=("-var=k8s_lb_influxdb_ip=${otelcol_ip}")
    TF_CONFIG_VARS+=("-var=opnsense_base_port_number=${baseport_number}")
    TF_CONFIG_VARS+=("-var=use_nvidia_gpu=${use_nvidia_gpu}")
    # Set git remote domain for fluxcd
    # TODO : maybe do this only for TF_DEPLOY_ENV != production
    sed -i -E "s/flux_git_remote_domain(\s+)\=(\s+)\"(.*)\"/flux_git_remote_domain\1\=\2\"$(sh scripts/get_dev_machine_ip.sh)\"/" "terraform/${TF_FOLDER}/${TF_CONFIG_VARS_FILE}"
fi


cd "terraform/${TF_FOLDER}"
if [ "${TF_FOLDER}" == "k8s" ]; then
    # Only planning nodes
    pushd nodes
        tofu workspace select "${TF_DEPLOY_ENV}"
        tofu plan -out "${TF_FOLDER}.tfplan" -var-file="../${TF_CONFIG_VARS_FILE}" -var-file='../../env/credentials.tfvars' -var="registry_mirror_url=http://$(sh ../../../scripts/get_dev_machine_ip.sh):15000/v2"
    popd
else
    tofu plan -out "${TF_FOLDER}.tfplan" -var-file="${TF_CONFIG_VARS_FILE}" -var-file='../env/credentials.tfvars' "${TF_CONFIG_VARS[@]}"
fi