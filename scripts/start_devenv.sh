#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export GITEA_INSTANCE_NAME="dev_gitea"
export REPO_PATH=$(dirname $(dirname $(realpath "$0")))
podman compose -f $SCRIPTPATH/../dev/docker-compose.yaml up -d
