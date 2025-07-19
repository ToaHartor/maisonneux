#!/bin/bash

set -euo pipefail

# Use this script to restore the cluster to the latest backup available

bash ./scripts/restore/restore_cluster.sh "schedule"
bash ./scripts/restore/restore_mariadb.sh "schedule"
bash ./scripts/restore/restore_cnpg.sh