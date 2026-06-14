#!/bin/bash

set -euo pipefail

export REPO_PATH=$(dirname $(dirname $(realpath "$0")))

# Shut down instance if it exists
echo "Stopping running instance"
mise run devenv stop || true

# Remove persistent data from old instances
sudo rm -rf tmp/forgejo*
mkdir -p tmp/forgejo
mkdir -p tmp/forgejo-runner


# Following https://code.forgejo.org/forgejo/runner/src/branch/main/examples/docker-compose/compose-forgejo-and-runner.yml
# export FORGEJO_RUNNER_SHARED_SECRET=c2d4893ba032fc7dce1e3c9b616b018648fb3271 # openssl rand -hex 20
# export FORGEJO_RUNNER_UUID=63326434-3839-3362-6130-333266633764 # echo -n $FORGEJO_RUNNER_SHARED_SECRET | python -c 'import sys; import uuid;input=sys.stdin.read();print(str(uuid.UUID(bytes=input[:16].encode("utf-8"))))'

# Export common env variables
# shellcheck disable=SC2046
export $(grep -v '^#' "$REPO_PATH/dev/docker.env" | xargs)

# export FORGEJO_USERNAME="localdev"
# export FORGEJO_USER_EMAIL="${FORGEJO_USERNAME}@example.com"
# export FORGEJO_PASSWORD="password"
# export FORGEJO_NAME=$(git config --list | grep "user.name" | cut -d"=" -f2)
export FORGEJO_NAME="localdev"
# export FORGEJO_INSTANCE_NAME="dev_forgejo"

echo "Starting the local forgejo stack"
mise run devenv start

forgejo_addr="$(docker port "$FORGEJO_INSTANCE_NAME" 3000 | head -1)"
forgejo_url="http://$forgejo_addr"
forgejo_local_repo_name="maisonneux-local"

# wait for gitea to be ready.
echo "Waiting for Forgejo to be ready at $forgejo_url..."
FORGEJO_URL="$forgejo_url" bash -euc 'while [ -z "$(wget -qO- "$FORGEJO_URL/api/v1/version" | jq -r ".version | select(.!=null)")" ]; do sleep 5; done'

export GIT_PUSH_REPOSITORY="http://$FORGEJO_USERNAME:$FORGEJO_PASSWORD@$forgejo_addr/$FORGEJO_USERNAME/${forgejo_local_repo_name}.git"

# Create admin user used for pushes
docker exec --user git "$FORGEJO_INSTANCE_NAME" forgejo admin user create \
    --admin \
    --email "$FORGEJO_USER_EMAIL" \
    --username "$FORGEJO_USERNAME" \
    --password "$FORGEJO_PASSWORD"
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$FORGEJO_USERNAME:$FORGEJO_PASSWORD" \
    -X 'PATCH' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"full_name\":\"$FORGEJO_NAME\"}" \
    "$forgejo_url/api/v1/user/settings" \
    | jq \
    > /dev/null

# Create repository
echo "Create repository in local git"
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$FORGEJO_USERNAME:$FORGEJO_PASSWORD" \
    -X POST \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"name\": \"$forgejo_local_repo_name\"}" \
    "$forgejo_url/api/v1/user/repos" \
    | jq \
    > /dev/null


# Prepare renovate folder
mkdir -p tmp/renovate

docker exec --user git "$FORGEJO_INSTANCE_NAME" forgejo admin user create \
    --admin \
    --email "$RENOVATE_USERNAME@example.com" \
    --username "$RENOVATE_USERNAME" \
    --password "$RENOVATE_PASSWORD" \
    --must-change-password=false
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$RENOVATE_USERNAME:$RENOVATE_PASSWORD" \
    -X 'PATCH' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"full_name\":\"$RENOVATE_NAME\"}" \
    "$forgejo_url/api/v1/user/settings" \
    | jq \
    > /dev/null

# Add the user to the repository
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$FORGEJO_USERNAME:$FORGEJO_PASSWORD" \
    -X 'PUT' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{"permission": "admin"}' \
    "$forgejo_url/api/v1/repos/$FORGEJO_USERNAME/${forgejo_local_repo_name}/collaborators/$RENOVATE_USERNAME" \
    | jq \
    > /dev/null


# create the user personal access token for renovate
# see https://docs.gitea.io/en-us/api-usage/
# see https://docs.gitea.io/en-us/oauth2-provider/#scopes
# see https://try.gitea.io/api/swagger#/user/userCreateToken
echo "Creating Forgejo $RENOVATE_USERNAME user personal access token..."
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -u "$RENOVATE_USERNAME:$RENOVATE_PASSWORD" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "renovate", "scopes": ["read:user", "write:issue", "write:repository", "read:organization"]}' \
    "$forgejo_url/api/v1/users/$RENOVATE_USERNAME/tokens" \
    | jq -r .sha1 \
    >tmp/renovate/renovate-forgejo-token.txt

# try the token.
echo "Trying the Forgejo $RENOVATE_USERNAME user personal access token for renovate..."
RENOVATE_TOKEN="$(cat tmp/renovate/renovate-forgejo-token.txt)"
export RENOVATE_TOKEN
curl \
    --silent \
    --show-error \
    --fail-with-body \
    -H "Authorization: token $RENOVATE_TOKEN" \
    -H 'Accept: application/json' \
    "$forgejo_url/api/v1/version" \
    | jq \
    > /dev/null

# Setup git as another remote repository
# This should also change urls for existing branches
echo "Force push to local remote"
git push --force "$GIT_PUSH_REPOSITORY"
echo "Setting git localorigin remote to our local git"
git remote set-url localorigin "$GIT_PUSH_REPOSITORY" || git remote add localorigin "$GIT_PUSH_REPOSITORY"

echo "Local Forgejo deployed successfully !"
echo "Now create a new branch or use an existing one then define its remote repo to localorigin"
echo "using 'git push -u localorigin <branch>'"
