#!/bin/bash

set -euo pipefail

# Backups managed by velero
velero backup create --from-schedule velero-global --wait
# velero backup create --from-schedule velero-mariadb --wait
