#!/bin/bash

set -euo pipefail

# Use this script to restore the cluster to the latest backup available, or to a specific backup when asked

function backup_handler() {
  backup_script="$1"
  read -p "Running $backup_script, backup ([y]es/[n]o) : " backup_input

  case $backup_input in
    "y" | "yes" )
      BACKUP_ARG=""
      echo "Starting $backup_script..."
      bash "./scripts/backup/${backup_script}.sh" "$BACKUP_ARG"
      ;;
    *)
      echo "Skipping $backup_script."
  esac
}

backup_handler "backup_cluster"
backup_handler "backup_cnpg"