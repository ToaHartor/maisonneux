#!/bin/bash
set -euo pipefail

function tfutils::get_folder_env() {
  # Input : folder[-env] as $1
  # Output : define TF_FOLDER, TF_CONFIG_VARS_FILE and 
  # readarray -d '' FLUXCD_ENVS < <(find terraform/fluxcd/terraform.tfstate.d/* -type d -exec basename {} \;)
  FLUXCD_ENVS=("production" "staging")

  # Match env based on the prefix
  FLUXCD_ENV=$(printf "%s\n" "${FLUXCD_ENVS[@]}" | sed -n "/${1#fluxcd-*}/p")
  K8S_ENV=$(printf "%s\n" "${FLUXCD_ENVS[@]}" | sed -n "/${1#k8s-*}/p")

  # Default when no env (e.g static)
  TF_DEPLOY_ENV=""
  TF_FOLDER=$1
  TF_CONFIG_VARS_FILE="config.tfvars"

  if [ "${FLUXCD_ENV}" != "" ]; then
    TF_FOLDER=fluxcd
    TF_DEPLOY_ENV=${FLUXCD_ENV}
  elif [ "${K8S_ENV}" != "" ]; then
    TF_FOLDER=k8s
    TF_DEPLOY_ENV=${K8S_ENV}
  fi

  if [ "${TF_DEPLOY_ENV}" != "" ]; then
    TF_CONFIG_VARS_FILE="config.${TF_DEPLOY_ENV}.tfvars"
  fi

  export TF_FOLDER
  export TF_CONFIG_VARS_FILE
  export TF_DEPLOY_ENV
}

function tfutils::get_tfvars_quoted_key() {
  key=$1
  tfvar_file=$2
  grep -Po "${key}\s*\=\s*\"[^\"\s]+" < "${tfvar_file}" | cut -d '"' -f2
}

function tfutils::get_tfvars_number_key() {
  key=$1
  tfvar_file=$2
  grep -Po "${key}\s*\=\s*\d+" < "${tfvar_file}" | cut -d '=' -f2 | awk '{$1=$1};1'
}

function tfutils::get_tfvars_boolean_key() {
  key=$1
  tfvar_file=$2
  grep -Po "${key}\s*\=\s*\w+" < "${tfvar_file}" | cut -d '=' -f2 | awk '{$1=$1};1'
}