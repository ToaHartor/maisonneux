# Upgrading components and dependencies of a cluster

## OS and Kubernetes upgrades

Everything is bundled in `scripts/upgrade_node_os.sh` and `scripts/upgrade_k8s.sh`. Always test an upgrade on a staging cluster before doing it in production.

If one day it becomes possible to upgrade Kubernetes and Talos using the Talos provider, then we would be able to get rid of them.

### Talos Linux

Rollback is quite easy with `talosctl rollback --nodes <target-node-ip>`

In case extensions or kernel arguments must be modified, modify the file `scripts/talos_schematic.yaml` then run an update with the same version.

## Charts installed with Terraform

- Run Renovate to create Pull requests
- Merge the pull requests
- Run the target Terraform deployment depending on the chart (plan & apply)

This upgrade process concern the following charts :

- Flux2 and Flux2Sync (fluxcd terraform)
- Cilium (k8s terraform)

### Cilium

Cilium has its own process described here : <https://docs.cilium.io/en/stable/operations/upgrade/>

Few things to note before upgrading :

- Pull request made by Renovate will only be used as reference, but will not actually be merged.
- The only tested upgrade and rollback path is between consecutive minor releases. Always perform upgrades and rollbacks between one minor release at a time. Additionally, always update to the latest patch release of your current version before attempting an upgrade.
- Read the release check before : <https://docs.cilium.io/en/stable/operations/upgrade/#current-release-required-changes>

Upgrade process:

- Do modifications in the target environment tfvars file (k8s)
- Check if some defaults have changed in the upgrade notes, and modify the values manifest accordingly (`scripts/manifests/cilium_values.yaml`). As we do not set upgradeCompatibility, we need to check the default values for major versions in <https://github.com/search?q=repo%3Acilium%2Fcilium%20upgradeCompatibility&type=code>
- Run the pre-flight check with the script `scripts/cilium_preflight.sh <environment> <target-version>`
- Upgrade to the latest patch using Terraform deployment

- Commit the changes when all clusters are upgraded

In case a rollback is needed, use the rollback feature of helm :

```bash
helm history cilium --namespace=kube-system
helm rollback cilium [REVISION] --namespace=kube-system
```

## Applications

### Seafile upgrade (application major version only)

- Check if any structural change were done in the Docker image (<https://github.com/haiwen/seafile-docker/tree/master>)
- Check if start.py script changed the database init functions (e.g. <https://github.com/haiwen/seafile-docker/blob/master/scripts/scripts_12.0/start.py#L44>)
- Check changes in bootstrap.py about `init_seafile_server()` (e.g. <https://github.com/haiwen/seafile-docker/blob/master/scripts/scripts_12.0/bootstrap.py#L128>)
- Modify the init container in ./helm/apps/sefile/values.yaml (only used for cluster init, not for upgrades)

### MariaDB operator

- Delete HelmResource mariadb-operator (pause Kustomization reconciliation ?)
- Merge MR in Gitea
- Let platform Kustomization reconcile and recreate mariadb-operator
- Same steps for production on GitHub

### CloudNative PG operator

- Check the release documentation for additional steps <https://cloudnative-pg.io/documentation/preview/release_notes/>
- Outside of those potential additional steps, it should auto-update when merging the PR made by Renovate

### TrueCharts dependencies update

Usually minor updates focus on minor updates of containers. (Maybe configure Renovate to auto-merge when a TrueChart chart has a minor update)

Major updates of either the common chart or major image version updates generate a major version of the chart. In this case, check the changelog as always, but also the changelog of the application and the changelog of the common library <https://truecharts.org/charts/library/common/changelog/#_top>.
