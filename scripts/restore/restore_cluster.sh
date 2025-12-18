#!/bin/bash

set -euo pipefail

# This script is used to restore a backup on an existing cluster

DEPLOYMENTS=(
  # When an annotation is added to a pvvc that should be backed up, add an entry to the following array
  # Format : "deployment, namespace, pvc1|pvc2, appname"
  "suwayomi-tachidesk-docker, media, suwayomi-tachidesk-docker-appdata, tachidesk-docker"
  "kavita, media, kavita-config, kavita"
  "opencloud, services, opencloud, opencloud"
  "qbittorrent, media, qbittorrent-config, qbittorrent"
  "jellyfin, jellyfin, jellyfin-config|jellyfin-data, jellyfin"
)

if [ -z "$1" ]; then
  echo "No backup schedule or backup name is given. Parameter should be either 'schedule' for the latest schedule, or <backup-name> for a specific one. Add --staged to separate secret restore from pvc."
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
  velero restore create --restore-volumes -l "app.kubernetes.io/name=${appname}" --exclude-resources externalsecrets,secrets,pv $BACKUP_ARG -w
  post_restore_deploy "$deploy" "$namespace" "$pvc"
}


function pre_restore_deploy() {
  deploy="$1"
  namespace="$2"
  pvc="$3"
  # Scale down deployment to zero
  kubectl scale --replicas=0 "deployment/$deploy" -n "$namespace"

  IFS='|' read -r -a pvcarray <<< "$pvc"

  # Remove PVC(s)
  for element in "${pvcarray[@]}"
  do
    kubectl delete "pvc/$element" -n "$namespace" --ignore-not-found
  done

  # Scale up again directly after, it will wait for the pvc to be released by the restore job and available
  kubectl scale --replicas=1 "deployment/$deploy" -n "$namespace"

}

function post_restore_deploy() {
  deploy="$1"
  namespace="$2"
  pvc="$3"

  IFS='|' read -r -a pvcarray <<< "$pvc"

  # Wait for PVC to be bound
  for element in "${pvcarray[@]}"
  do
    kubectl wait --for=jsonpath='{.status.phase}'=Bound "pvc/$element" -n "$namespace" --timeout 5m
  done
}


function restore_all() {
  # Delete all pvcs at once

  for deployment in "${DEPLOYMENTS[@]}"
  do
    IFS=', ' read -r -a deployArgs <<< "$deployment"
    
    pre_restore_deploy "${deployArgs[@]}"

  done

  # Restore everything
  # shellcheck disable=SC2086
  velero restore create --restore-volumes --include-cluster-resources --exclude-resources pv $BACKUP_ARG --existing-resource-policy update -w

  # Wait for pvc to be bound
  for deployment in "${DEPLOYMENTS[@]}"
  do
    IFS=', ' read -r -a deployArgs <<< "$deployment"
    
    post_restore_deploy "${deployArgs[@]}"

  done

}

function restore_staged() {
    # Restore externalsecrets and secrets
  # shellcheck disable=SC2086
  velero restore create --include-cluster-resources --exclude-resources pv,pvc $BACKUP_ARG --existing-resource-policy update -w

  # Restore individual pvc loop
  for deployment in "${DEPLOYMENTS[@]}"
  do
    IFS=', ' read -r -a deployArgs <<< "$deployment"
    restore_deploy_pvc "${deployArgs[@]}"
    sleep 1 # in order to not have colliding restores if it already exists
  done
}

if [ $# -lt 2 ] || [ "$2" != "--staged" ]; then
  restore_all
else
  restore_staged
fi

echo "Do not forget to clean the remaining PersistentVolumes :"
kubectl get pv | grep Released