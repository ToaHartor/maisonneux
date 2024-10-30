#!/bin/bash

# Reference for gitea user and repo init
# from https://raw.githubusercontent.com/rgl/terraform-proxmox-talos/refs/heads/main/renovate.sh

set -euo pipefail

export REPO_PATH=$(dirname $(dirname $(realpath "$0")))

# Shut down instance if it exists
echo "Stopping running instance"
docker compose -f dev/docker-compose.yaml down || true

# Remove persistent data from old instances
rm -rf tmp/gitea
mkdir -p tmp/gitea/data
mkdir -p tmp/gitea/config

# export reused variables, use GitHub info for Gitea
# export GITEA_USER_EMAIL=$(git config --list | grep "user.email" | cut -d"=" -f2)
# export GITEA_USERNAME=$(echo "$GITEA_USER_EMAIL" | cut -d"@" -f1)
export GITEA_USERNAME="localdev"
export GITEA_USER_EMAIL="${GITEA_USERNAME}@example.com"
export GITEA_PASSWORD="password"
# export GITEA_NAME=$(git config --list | grep "user.name" | cut -d"=" -f2)
export GITEA_NAME="localdev"
export GITEA_INSTANCE_NAME="dev_gitea"

echo "Starting the local gitea stack"
docker compose -f dev/docker-compose.yaml up -d

gitea_addr="$(docker port "$GITEA_INSTANCE_NAME" 3000 | head -1)"
gitea_url="http://$gitea_addr"
gitea_local_repo_name="maisonneux-local"

# wait for gitea to be ready.
echo "Waiting for Gitea to be ready at $gitea_url..."
GITEA_URL="$gitea_url" bash -euc 'while [ -z "$(wget -qO- "$GITEA_URL/api/v1/version" | jq -r ".version | select(.!=null)")" ]; do sleep 5; done'

export GIT_PUSH_REPOSITORY="http://$GITEA_USERNAME:$GITEA_PASSWORD@$gitea_addr/$GITEA_USERNAME/${gitea_local_repo_name}.git"

# Create admin user used for pushes
docker exec --user git "$GITEA_INSTANCE_NAME" gitea admin user create \
    --admin \
    --email "$GITEA_USER_EMAIL" \
    --username "$GITEA_USERNAME" \
    --password "$GITEA_PASSWORD"
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -X 'PATCH' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"full_name\":\"$GITEA_NAME\"}" \
    "$gitea_url/api/v1/user/settings" \
    | jq \
    > /dev/null

# Create repository
echo "Create repository in local git"
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -X POST \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"name\": \"$gitea_local_repo_name\"}" \
    "$gitea_url/api/v1/user/repos" \
    | jq \
    > /dev/null

# Setup git as another remote repository
# This should also change urls for existing branches
echo "Force push to local remote"
git push --force "$GIT_PUSH_REPOSITORY"
echo "Setting git localorigin remote to our local git"
git remote set-url localorigin "$GIT_PUSH_REPOSITORY" || git remote add localorigin "$GIT_PUSH_REPOSITORY"

echo "Local Gitea deployed successfully !"
echo "Now create a new branch or use an existing one then define its remote repo to localorigin"
