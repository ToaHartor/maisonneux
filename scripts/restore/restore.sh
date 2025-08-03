#!/bin/bash

set -euo pipefail

# Use this script to restore the cluster to the latest backup available, or to a specific backup when asked

function restore_handler() {
  restore_script="$1"
  read -p "Running option for $restore_script, restoring secrets/pvc ([s]kip/[l]atest/backup name) : " backup_input

  case $backup_input in
    "s" | "skip" | "")
      echo "Skipping $restore_script."
      BACKUP_ARG=""
      ;;
    "l" | "latest")
      BACKUP_ARG="schedule"
      ;;
    *)
      BACKUP_ARG="$backup_input"
  esac

  if [[ -n "$BACKUP_ARG" ]]; then
    echo "Starting $restore_script..."
    bash "./scripts/restore/${restore_script}.sh" "$BACKUP_ARG"
  fi
}

restore_handler "restore_cluster"
restore_handler "restore_mariadb"

# CNPG has a bug when restoring the latest backup with targetTime, so we need to specify a target backup
# https://github.com/cloudnative-pg/cloudnative-pg/issues/5177

restore_handler "restore_cnpg"