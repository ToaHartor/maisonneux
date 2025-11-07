#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export GITEA_INSTANCE_NAME="dev_gitea"
export REPO_PATH=$(dirname $(dirname $(realpath "$0")))


source "./scripts/utils/tf-utils.sh"

TARGET_TFVARS="${REPO_PATH}/terraform/fluxcd/config.production.tfvars"

# Add minio credentials from production env
# shellcheck disable=SC2155
export MINIO_ACCESS_KEY=$(tfutils::get_tfvars_quoted_key "minio_access_key" "${TARGET_TFVARS}")
# shellcheck disable=SC2155
export MINIO_SECRET_KEY=$(tfutils::get_tfvars_quoted_key "minio_secret_key" "${TARGET_TFVARS}")

MINIO_ADDRESS=$(tfutils::get_tfvars_quoted_key "minio_access_url" "${TARGET_TFVARS}")

# Set zot remote storage to the minio bucket in truenas
jq ".storage.storageDriver.regionendpoint |= \"http://${MINIO_ADDRESS}\"" "${REPO_PATH}/dev/zot-config.json" > "${REPO_PATH}/tmp/zot-config.json"
mkdir -p "${REPO_PATH}/tmp/zot"

podman compose -f "$SCRIPTPATH/../dev/docker-compose.yaml" up -d
