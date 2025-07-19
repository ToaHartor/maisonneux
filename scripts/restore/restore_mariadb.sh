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
pvcs=(storage-mariadb-galera-0 storage-mariadb-galera-1 storage-mariadb-galera-2)

function suspend_mariadb_resource() {
  suspend="$1"
  kubectl patch mariadb -n "$namespace" mariadb-galera --type merge -p "{\"spec\": {\"suspend\": $suspend}}"
}

# Suspend MariaDB resource for the operator
suspend_mariadb_resource "true"

# Scale statefulset to zero
kubectl scale --replicas=0 "statefulset/mariadb-galera" -n "$namespace"
# Remove PVCs
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

# Scale up again
kubectl scale --replicas=3 "statefulset/mariadb-galera" -n "$namespace"

# Wait until main pod is ready
kubectl wait --for=condition=Ready pod/mariadb-galera-0 -n "$namespace" --timeout 5m

# Enable write again in the cluster
# shellcheck disable=SC2016
kubectl exec -n "$namespace" mariadb-galera-0 -it -c mariadb -- /bin/sh -c 'mariadb -u root --password=$MARIADB_ROOT_PASSWORD -e "UNLOCK TABLES"'

# Unsuspend MariaDB resource
suspend_mariadb_resource "false"