#!/bin/bash

set -euo pipefail

export GITEA_INSTANCE_NAME="dev_gitea"
export REPO_PATH=$(dirname $(dirname $(realpath "$0")))
docker compose -f dev/docker-compose.yaml up -d
