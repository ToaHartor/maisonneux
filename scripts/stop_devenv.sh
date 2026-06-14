#!/bin/bash

set -euo pipefail

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

export REPO_PATH=$(dirname $(dirname $(realpath "$0")))

docker compose -f "$SCRIPTPATH/../dev/docker-compose.yaml" --env-file "$SCRIPTPATH/../dev/docker.env" down
