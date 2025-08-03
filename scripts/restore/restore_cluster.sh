#!/bin/bash

set -euo pipefail

# This script is used to restore a backup on an existing cluster

DEPLOYMENTS=(
  # Format : "deployment, namespace, pvc, appname"
  "suwayomi-tachidesk-docker, media, suwayomi-tachidesk-docker-appdata, tachidesk-docker"
  "kavita, media, kavita-config, kavita"
)

if [ -z "$1" ]; then
  echo "No backup schedule or backup name is given. Parameter should be either 'schedule' for the latest schedule, or <backup-name> for a specific one."
  exit 1
fi

BACKUP_ARG="--from-schedule velero-global"
if [[ $1 != "schedule" ]]; then
  if ! velero get backup "$1" ; then
    echo "Backup $1 could not be found"
  fi
  echo "Using backup $1"
  BACKUP_ARG="--from-backup $1"
else
  echo "Using latest scheduled backup"
fi


function restore_deploy_pvc() {
  deploy="$1"
  namespace="$2"
  pvc="$3"
  appname="$4"

  pre_restore_deploy "$deploy" "$namespace" "$pvc"
  # shellcheck disable=SC2086
  velero restore create --restore-volumes --include-cluster-resources -l "app.kubernetes.io/name=${appname}" --exclude-resources externalsecrets,secrets $BACKUP_ARG -w
  post_restore_deploy "$deploy" "$namespace" "$pvc"
}


function pre_restore_deploy() {
  deploy="$1"
  namespace="$2"
  pvc="$3"
  # Scale down deployment to zero
  kubectl scale --replicas=0 "deployment/$deploy" -n "$namespace"
  # Remove PVC
  kubectl delete "pvc/$pvc" -n "$namespace"
}

function post_restore_deploy() {
  deploy="$1"
  namespace="$2"
  pvc="$3"
  # Wait for PVC to be bound
  kubectl wait --for=jsonpath='{.status.phase}'=Bound "pvc/$pvc" -n "$namespace" --timeout 5m
  # Scale up again
  kubectl scale --replicas=1 "deployment/$deploy" -n "$namespace"
}

# Restore externalsecrets and secrets
# shellcheck disable=SC2086
velero restore create --include-cluster-resources --exclude-resources pv,pvc $BACKUP_ARG --existing-resource-policy update -w

# Restore individual pvc loop
for deployment in "${DEPLOYMENTS[@]}"
do
  IFS=', ' read -r -a deployArgs <<< "$deployment"
  restore_deploy_pvc "${deployArgs[@]}"
done

echo "Do not forget to clean the remaining PersistentVolumes :"
kubectl get pv | grep Released