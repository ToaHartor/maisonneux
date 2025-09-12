#!/bin/bash

set -euo pipefail

# Use this script to immediately backup the cluster

# Backups managed by velero
velero backup create --from-schedule velero-global --wait
velero backup create --from-schedule velero-mariadb --wait

# Backups managed by cnpg
kubectl cnpg backup psql-cluster -n "postgres" --method "plugin" --plugin-name "barman-cloud.cloudnative-pg.io" --immediate-checkpoint "true" --wait-for-archive "true"
kubectl cnpg backup immich-psql-cluster -n "immich" --method "plugin" --plugin-name "barman-cloud.cloudnative-pg.io" --immediate-checkpoint "true" --wait-for-archive "true"
