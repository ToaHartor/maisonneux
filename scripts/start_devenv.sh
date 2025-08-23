#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export GITEA_INSTANCE_NAME="dev_gitea"
export REPO_PATH=$(dirname $(dirname $(realpath "$0")))

function get_tfvars_quoted_key() {
  key=$1
  tfvar_file=$2
  grep -Po "${key}\s*\=\s*\"[^\"\s]+" < "${tfvar_file}" | cut -d '"' -f2
}

function get_tfvars_number_key() {
  key=$1
  tfvar_file=$2
  grep -Po "${key}\s*\=\s*\d+" < "${tfvar_file}" | cut -d '=' -f2 | awk '{$1=$1};1'
}

TARGET_TFVARS="${REPO_PATH}/terraform/k8s/config.production.tfvars"

# Add minio credentials from production env
# shellcheck disable=SC2155
export MINIO_ACCESS_KEY=$(get_tfvars_quoted_key "minio_access_key" "${TARGET_TFVARS}")
# shellcheck disable=SC2155
export MINIO_SECRET_KEY=$(get_tfvars_quoted_key "minio_secret_key" "${TARGET_TFVARS}")

TRUENAS_HOST=$(get_tfvars_quoted_key "truenas_vm_host" "${TARGET_TFVARS}")
MINIO_PORT=$(get_tfvars_number_key "minio_port" "${TARGET_TFVARS}")

# Set zot remote storage to the minio bucket in truenas
jq ".storage.storageDriver.regionendpoint |= \"http://${TRUENAS_HOST}:${MINIO_PORT}\"" "${REPO_PATH}/dev/zot-config.json" > "${REPO_PATH}/tmp/zot-config.json"

podman compose -f "$SCRIPTPATH/../dev/docker-compose.yaml" up -d
