#!/bin/bash

set -euo pipefail

if [ -z "$1" ]; then
  echo "No backup schedule or backup name is given. Parameter should be either 'schedule' for the latest schedule, or <backup-name> for a specific one."
  exit 1
fi

BACKUP_ARG="--from-schedule velero-mariadb"
if [[ $1 != "schedule" ]]; then
  if ! velero get backup "$1" ; then
    echo "Backup $1 could not be found"
  fi
  echo "Using backup $1"
  BACKUP_ARG="--from-backup $1"
else
  echo "Using latest scheduled backup"
fi

namespace="mariadb"
clusterName="mariadb-galera"
pvcs=("storage-${clusterName}-0" "storage-${clusterName}-1" "storage-${clusterName}-2")

function suspend_mariadb_resource() {
  suspend="$1"
  kubectl patch mariadb -n "$namespace" "${clusterName}" --type merge -p "{\"spec\": {\"suspend\": $suspend}}"
}

suspend_mariadb_resource "true"

kubectl scale --replicas=0 "statefulset/${clusterName}" -n "$namespace"

for pvc in "${pvcs[@]}"
do
  kubectl delete "pvc/$pvc" -n "$namespace" || true
done

# Restore
# shellcheck disable=SC2086
velero restore create --restore-volumes --include-cluster-resources $BACKUP_ARG -w

for pvc in "${pvcs[@]}"
do
  kubectl wait --for=jsonpath='{.status.phase}'=Bound "pvc/$pvc" -n "$namespace" --timeout 5m
done

kubectl scale --replicas=3 "statefulset/${clusterName}" -n "$namespace"
kubectl wait --for=condition=Ready "pod/${clusterName}-0" -n "$namespace" --timeout 5m

# Enable write again in the cluster, as backup hook disabled it before
# shellcheck disable=SC2016
kubectl exec -n "$namespace" "${clusterName}-0" -it -c mariadb -- /bin/sh -c 'mariadb -u root --password=$MARIADB_ROOT_PASSWORD -e "UNLOCK TABLES"'

suspend_mariadb_resource "false"

kubectl wait --for=condition=Ready "mariadb.k8s.mariadb.com/${clusterName}" -n "$namespace" --timeout=10m