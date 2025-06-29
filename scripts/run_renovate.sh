#!/bin/bash

set -euo pipefail

# see https://hub.docker.com/r/renovate/renovate/tags
# renovate: datasource=docker depName=renovate/renovate
renovate_version='40.14.4'

DRY_RUN_ARG=""
if [ $# -eq 1 ]; then
    if [ "$1" = "--dry-run" ]; then
        DRY_RUN_ARG="--dry-run=lookup"
    fi
fi

export GITEA_USERNAME="localdev"
export RENOVATE_USERNAME="renovate"
export RENOVATE_PASSWORD="password"
export GITEA_INSTANCE_NAME="dev_gitea"

gitea_local_repo_name="maisonneux-local"
gitea_addr="$(podman port "$GITEA_INSTANCE_NAME" 3000 | head -1)"
gitea_url="http://$gitea_addr"

# see https://docs.github.com/en/rest/rate-limit#get-rate-limit-status-for-the-authenticated-user
# see https://github.com/settings/tokens
# NB this is only used for authentication. the token should not have any scope enabled.
export GITHUB_COM_TOKEN=$(cat tmp/renovate/renovate-github-token.txt)
if [[ $GITHUB_COM_TOKEN = '' ]]; then
    echo "You must provide a github.com access token in tmp/renovate/renovate-github-token.txt for github dependencies fetching."
    exit 1
fi

rm -f tmp/renovate/*.json

# see https://docs.renovatebot.com/modules/platform/gitea/
# see https://docs.renovatebot.com/self-hosted-configuration/#dryrun
# see https://github.com/renovatebot/renovate/blob/main/docs/usage/examples/self-hosting.md
# see https://github.com/renovatebot/renovate/tree/main/lib/modules/datasource
# see https://github.com/renovatebot/renovate/tree/main/lib/modules/versioning
echo 'Running renovate...'
# NB use --dry-run=lookup for not modifying the repository (e.g. for not
#    creating pull requests).
# Configuration will be retrieved from the repository, so no need to pass the configuration to the container
podman run \
  --rm \
  --tty \
  --interactive \
  --net host \
  --env GITHUB_COM_TOKEN \
  --env RENOVATE_ENDPOINT=$gitea_url \
  --env RENOVATE_TOKEN=$(cat tmp/renovate/renovate-gitea-token.txt) \
  --env RENOVATE_REPOSITORIES=$GITEA_USERNAME/$gitea_local_repo_name \
  --env RENOVATE_PR_HOURLY_LIMIT=0 \
  --env RENOVATE_PR_CONCURRENT_LIMIT=0 \
  --env RENOVATE_BASE_BRANCHES=$(git rev-parse --abbrev-ref HEAD) \
  --env LOG_LEVEL=debug \
  --env LOG_FORMAT=json \
  "ghcr.io/renovatebot/renovate:$renovate_version" \
  --platform=gitea \
  --git-url=endpoint \
  $DRY_RUN_ARG \
  >tmp/renovate/renovate-log.json

echo 'Getting results...'
# extract the errors.
jq 'select(.err)' tmp/renovate/renovate-log.json >tmp/renovate/renovate-errors.json
# extract the result from the renovate log.
jq 'select(.msg == "packageFiles with updates") | .config' tmp/renovate/renovate-log.json >tmp/renovate/renovate-result.json
# extract all the dependencies.
jq 'to_entries[].value[] | {packageFile,dep:.deps[]}' tmp/renovate/renovate-result.json >tmp/renovate/renovate-dependencies.json
# extract the dependencies that have updates.
jq 'select((.dep.updates | length) > 0)' tmp/renovate/renovate-dependencies.json >tmp/renovate/renovate-dependencies-updates.json

# helpers.
function show_title {
    echo
    echo '#'
    echo "# $1"
    echo '#'
    echo
}

# show errors.
if [ "$(jq --slurp length tmp/renovate/renovate-errors.json)" -ne '0' ]; then
    show_title errors
    jq . tmp/renovate/renovate-errors.json
fi

# show dependencies.
function show_dependencies {
    show_title "$1"
    (
        printf 'packageFile\tdatasource\tdepName\tcurrentValue\tnewVersions\tskipReason\twarnings\n'
        jq \
            -r \
            '[
                .packageFile,
                .dep.datasource,
                .dep.depName,
                .dep.currentValue,
                (.dep | select(.updates) | .updates | map(.newVersion) | join(" | ")),
                .dep.skipReason,
                (.dep | select(.warnings) | .warnings | map(.message) | join(" | "))
            ] | @tsv' \
            "$2" \
            | sort
    ) | column -t -s "$(printf \\t)"
}
show_dependencies 'Dependencies' tmp/renovate/renovate-dependencies.json
show_dependencies 'Dependencies Updates' tmp/renovate/renovate-dependencies-updates.json

if [[ $DRY_RUN_ARG = "" ]]; then
    # show the gitea project.
    show_title "See PRs at $gitea_url/$RENOVATE_USERNAME/$gitea_local_repo_name/pulls (you can login as $RENOVATE_USERNAME:$RENOVATE_PASSWORD)"
else
    echo "Run 'make renovate' to generate PRs for dependencies" 
fi