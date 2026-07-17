# Operation : FluxCD helm bootstrap to FluxCD operator terraform bootstrap

Date : 2026/07/17

- Checkout localdev (head of prod) and ensure it is set in config
- make sure to reconcile both k8s and fluxcd terraform beforehand
- Checkout to new-fluxcd-bootstrap branch (branch rebased to localdev), prod is still in localdev
- Change `flux_git_branch` to `new-fluxcd-bootstrap` in fluxcd config
- Make sure `cluster_bootstrap` is set to `true` in k8s config
  - No need to migrate k8s-chart terraform state to `helm_release.cilium[0]` as it uses the state in the cluster
- Run terraform k8s chart, this will remove the chart from the state and set `cluster_bootstrap` to `false`

- Remove helm releases in terraform flux :

```bash
mr ctx <context>
cd terraform/fluxcd
tofu workspace select <context>
tofu state rm helm_release.fluxcd
tofu state rm helm_release.fluxcd_sync
```

- Uninstall old controllers manually

```bash
flux-operator -n flux-system uninstall --keep-namespace
```

This will delete crds but will not delete pods or anything else. Kustomization and HelmRelease object (and Helm resources) are kept as well.

- Delete `flux2` and `flux-system` helm resources in kubernetes
- Delete flux-system/flux-git-credentials from both terraform and as it is now managed by flux-operator and it does not exist in terraform anymore

```bash
mr ctx <context>
kubectl delete secret flux-git-credentials -n flux-system
cd terraform/fluxcd
tofu workspace select <context>
tofu state rm kubernetes_secret_v1.flux_git_credentials
```

- Run terraform fluxcd to bootstrap the operator
- Once done, merge branch in localdev and set `flux_git_branch` back to `localdev`
- Re-apply terraform fluxcd
