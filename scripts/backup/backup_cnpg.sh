#!/bin/bash

set -euo pipefail

# Backups managed by cnpg
kubectl cnpg backup psql-cluster -n "postgres" --method "plugin" --plugin-name "barman-cloud.cloudnative-pg.io" --immediate-checkpoint "true" --wait-for-archive "true"
