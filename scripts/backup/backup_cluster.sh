#!/bin/bash

set -euo pipefail

VELERO_NAMESPACE="system-backup"

# Backups managed by velero
velero backup create -n "$VELERO_NAMESPACE" --from-schedule velero-global --wait
# velero backup create -n "$VELERO_NAMESPACE" --from-schedule velero-mariadb --wait
