#!/bin/bash

set -euo pipefail


# Recovery prefix (default is "-temp" in terraform)
cnpgRecoveryPrefix="$(kubectl get configmap -n flux-system general-config -o=jsonpath='{.data.psql_suffix}')"
# so that if we restore in place it does not use prefixes


# cnpgRecoveryPrefix=""
backupSource="minio-backup" # ObjectStore names
# targetTime="2025-08-02 22:10:50.00000+02"

# Using current time does not seem to work, as last WAL does not exist ? https://github.com/cloudnative-pg/cloudnative-pg/discussions/2989
# WAL are archived by default every 5 minutes, if no timestamp is given, use current time minus 10 minutes to be safe ?
if [ $# -eq 0 ]; then
  targetTime="$(TZ="Europe/Paris" date -d '10 minutes ago' --rfc-3339=seconds)"
  echo "No backup timestamp provided, using current date : $targetTime"
else
  targetTime="$(date -d "$1" --rfc-3339=seconds)"
fi

# Also suspend corresponding Kustomization
# parentKustomization=$(kubectl get helmreleases.helm.toolkit.fluxcd.io "$helmrelease" -n "$namespace" -o=jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}')

function restore_database() {
  namespace="$1"
  helmrelease="$2"
  targetRestoreCluster="$3"
  sourceRecoveryCluster="${targetRestoreCluster}${cnpgRecoveryPrefix}"

  replicas=$4

  # Stop fluxcd before modifying resource
  echo "Suspending fluxcd release for helmrelease $helmrelease"
  flux suspend helmrelease "$helmrelease" -n "$namespace"

  # Hibernate source cluster
  kubectl cnpg hibernate on "$sourceRecoveryCluster" -n "$namespace" || true
  kubectl cnpg maintenance set "$sourceRecoveryCluster" -n "$namespace"

  # Destroy existing instances
  # shellcheck disable=SC2086
  for i in $(seq 1 $replicas)
  do
    kubectl cnpg destroy "$sourceRecoveryCluster" "${i}" -n "$namespace" || true
  done

  # Wait PVC deletion
  sleep 5

  # Wait until primary pod is deleted
  kubectl wait --for=delete "pod/${sourceRecoveryCluster}-1" -n "$namespace" --timeout=10m


  # Patch new target name
  kubectl patch helmreleases.helm.toolkit.fluxcd.io -n "$namespace" "$helmrelease" --type json -p \
    "[{\"op\": \"replace\", \"path\": \"/spec/values/database/postgres/clusterName\", \"value\": \"${targetRestoreCluster}\"}]"

  # Reconcile will change sourceRecoveryCluster to targetRestoreCluster
  flux resume helmrelease "$helmrelease" -n "$namespace"
  # flux reconcile helmrelease "$helmrelease" -n "$namespace"

  # Add annotation to disable reconciliation
  kubectl patch cluster.postgresql.cnpg.io -n "$namespace" "$targetRestoreCluster" --type json -p \
    "[{\"op\": \"add\", \"path\": \"/metadata/annotations/cnpg.io~1reconciliationLoop\", \"value\": \"disabled\"}]"

  # Hibernate cluster once reconciliation is performed, as we do not want to create init
  kubectl cnpg hibernate on "$targetRestoreCluster" -n "$namespace" || true
  kubectl cnpg maintenance set "$targetRestoreCluster" -n "$namespace"

  # Set primary to the first pod
  # kubectl cnpg promote "$resource" 1 -n "$namespace"

  # Suspend again as we touch the Cluster resource
  flux suspend helmrelease "$helmrelease" -n "$namespace"

  sleep 3

  # Remove init-db pods
  # shellcheck disable=SC2086
  for i in $(seq 1 $replicas)
  do
    kubectl cnpg destroy "$targetRestoreCluster" "${i}" -n "$namespace" || true
  done

  # Wait for init pod deletion, as we do not want to initialize restore when the pod is still active
  kubectl wait --for=delete "pod/${targetRestoreCluster}-1-initdb" -n "$namespace" --timeout=10m
  # sleep 5

  # Wait for PVC deletion of init job, otherwise recovery job will be stuck
  kubectl wait --for=delete "pvc/${targetRestoreCluster}-1" -n "$namespace" --timeout=5m

  # Reset latest generated node
  ## https://github.com/cloudnative-pg/cloudnative-pg/issues/5235#issuecomment-2478585137
  kubectl patch clusters.postgresql.cnpg.io -n "$namespace" "$targetRestoreCluster" --type=merge --subresource status --patch 'status: {latestGeneratedNode: 0}'

  # Add recovery in bootstrap
  kubectl patch cluster.postgresql.cnpg.io -n "$namespace" "$targetRestoreCluster" --type merge -p \
    "{\"spec\": {\"externalClusters\": [{\"name\": \"$backupSource\", \"plugin\": {\"name\": \"barman-cloud.cloudnative-pg.io\", \"isWALArchiver\": false, \"parameters\": {\"barmanObjectName\": \"${backupSource}\", \"serverName\": \"$targetRestoreCluster\"}}}]}}"

  # Replace bootstrap method
  # Also add annotation to skip empty WAL archives, to bypass
  ## ERROR: WAL archive check failed for server recoveredCluster: Expected empty archive
  # Finally, enable reconciliation
  kubectl patch cluster.postgresql.cnpg.io -n "$namespace" "$targetRestoreCluster" --type json -p \
    "[{\"op\": \"add\", \"path\": \"/metadata/annotations/cnpg.io~1skipEmptyWalArchiveCheck\", \"value\": \"enabled\"}, {\"op\": \"replace\", \"path\": \"/spec/bootstrap\", \"value\": {\"recovery\": {\"source\": \"$backupSource\", \"recoveryTarget\": {\"targetTime\": \"$targetTime\"}}}}, {\"op\": \"remove\", \"path\": \"/metadata/annotations/cnpg.io~1reconciliationLoop\"}]"
    # "{\"metadata\": {\"annotations\": {\"cnpg.io/skipEmptyWalArchiveCheck\": \"enabled\"}}, \"spec\": {\"bootstrap\": {\"recovery\": {\"source\": \"$backupSource\", \"recoveryTarget\": {\"targetTime\": \"$targetTime\"}}}, }}"

  # Un-hibernate target cluster
  kubectl cnpg hibernate off "$targetRestoreCluster" -n "$namespace"
  kubectl cnpg maintenance unset "$targetRestoreCluster" -n "$namespace"

  # Wait until pods are healthy by importing the former
  kubectl wait --for=condition=Ready "cluster.postgresql.cnpg.io/${targetRestoreCluster}" -n "$namespace" --timeout="15m" || true

  # Delete bootstrap and externalClusters sections
  kubectl patch cluster.postgresql.cnpg.io -n "$namespace" "$targetRestoreCluster" --type json -p \
    '[{"op": "remove", "path": "/spec/bootstrap"}, {"op": "remove", "path": "/spec/externalClusters"}, {"op": "remove", "path": "/metadata/annotations/cnpg.io~1skipEmptyWalArchiveCheck"}]'

  echo "Do not forget to clean the remaining PersistentVolumes :"
  kubectl get pv | grep Released | grep "$sourceRecoveryCluster"

  echo "Run fluxcd again and reconcile kustomization"
  flux resume helmrelease "$helmrelease" -n "$namespace"
}

# Group databases by deployment phase
## Only suspend if prefix is not empty as values defined in HelmRelease are only changing in this case

# Platform
if [[ -n "$cnpgRecoveryPrefix" ]]; then
  flux suspend kustomization platform
fi

# Arguments : <namespace> <helmrelease> <target restore cluster> <replicas>
# restore_database "postgres" "psql-cluster" "psql-cluster" 3


# Apps
if [[ -n "$cnpgRecoveryPrefix" ]]; then
  flux suspend kustomization apps
fi
restore_database "immich" "immich-db" "immich-psql-cluster" 1


if [[ -n "$cnpgRecoveryPrefix" ]]; then
  echo "Last step : disable cnpg_recovery in terraform fluxcd, then resume Kustomization"
fi

# flux resume kustomization platform
# flux resume kustomization apps