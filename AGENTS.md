# Maisonneux - AI Assistant Guide

This is a **Home Kubernetes cluster monorepo** managed with GitOps (Flux, Renovate, Forgejo Actions).

## Repository Structure

```text
maisonneux/
├── .agents/                          # AI instructions & skills
│   └── instructions/                 # PR review system prompt, YAML sorting rules
├── .forgejo/                         # Forgejo Actions workflows & evidence providers
├── ansible/                          # Ansible playbooks (BGP peers setup)
├── dev/                              # Development stack (local development)
├── docs/                             # Documentation
├── helm/                             # Custom helm charts deploying specific apps
│   ├── apps/                         # Custom helm charts deployed in the Application stage
│   ├── common/                       # Custom helm charts deployed in all stages
│   ├── library/                      # Custom helm libraries used in custom helm charts
│   └── platform/                     # Custom helm charts deployed in the Platform stage
├── kubernetes/                       # Kubernetes configurations (Flux-managed)
│   ├── apps/                         # Application configs
│   │   ├── base/                     # Shared base configs
│   │   ├── production/               # Production cluster overlay (currently used)
│   │   └── staging/                  # Test cluster overlay
│   ├── clusters/                     # Flux cluster definitions
│   │   ├── production/               # Production cluster (currently used)
│   │   ├── staging/                  # Staging cluster
│   │   └── test/                     # Test overlay, used by flate/konflate for template rendering
│   ├── common/                       # Flux common components
│   │   ├── components/               # Kustomization components, common configs applied at namespace or app level
│   │   ├── patches/                  # Common patches
│   │   └── transformers/             # Kustomization transformers, applied in kustomization.yaml of namespace folders
│   ├── core/                         # Core apps configs, shares the same layout
│   ├── platform/                     # Platform apps configs
│   └── system/                       # System apps configs
├── scripts/                          # Various shell scripts
│   ├── backup/                       # Cluster backup scripts
│   ├── make/                         # Terraform scripts used in mise
│   └── restore/                      # Restore scripts
└── terraform/                        # OpenTofu/Terraform IaC (cloud infra) (see terraform/README.md)
    ├── fluxcd/                       # FluxCD in-cluster bootstrap
    ├── k8s/                          # Talos VM cluster deployment on proxmox
    └── static/                       # Static VMs providing services (TrueNAS, OPNSense, legacy VM...)

```

## Cluster Architecture

Proxmox cluster of two nodes :

- **datacenter** - Ryzen 7 5700X, RTX 5060Ti 16GB VRAM, 64GB RAM, 1.5TB NVME, 1.5TB SSD, 2.5GbE, hosts a TrueNAS VM (10TB mirror, 52TB raw)
- **cthugha** - 1x MS-A2 (Ryzen 9 7945HX, 64GB RAM, 1TB NVME, 10Gb SFP+)

Nodes are conencted to a **MikroTik CRS305-1G-4S** with 4x10Gb SFP+ ports.

## Key Technologies

| Category   | Tool                       | Purpose                                                                    |
| ---------- | -------------------------- | -------------------------------------------------------------------------- |
| GitOps     | Flux + flux-operator       | Deploys configs from Git to k8s; Flux instance is deployed using Terraform |
| CI         | Renovate + Forgejo Actions | Dependency updates, automation                                             |
| Networking | Cilium (eBPF)              | CNI, BGP, service mesh                                                     |
| Ingress    | Traefik                    | Ingress, Gateway API controller                                            |
| TLS        | cert-manager               | TLS certificate automation                                                 |
| Secrets    | external-secrets           | Secret management                                                          |
| Storage    | Linstor + Piraeus          | Distributed storage and in-cluster volume provisioner                      |
| Backups    | Velero + Barman cloud      | PVC/secrets and postgres backups                                           |
| Images     | spegel + zot               | Local OCI mirrors                                                          |
| IaC        | opentofu                   | Terraform on k8s                                                           |
| Charts     | app-template (bjw-s)       | Common Helm chart used by most apps                                        |
| Sources    | OCIRepository              | Flux source for OCI Helm charts (preferred)                                |
| Reviews    | konflate                   | Rendered-diff evidence provider for PR reviews                             |

## Key patterns

### App structure

Each app usually have those files :

- `kustomization.yaml` - Kustomize config
- `ks.yaml` - Flux Kustomization CRD
- `helmrelease.yaml` - Helm release config
- `ocirepository.yaml` - OCI chart source
- `externalsecret.yaml` - External Secret config (if needed)

### GitOps Flow

```text
Git push → Flux source sync → Kustomization → HelmRelease → k8s resources
```

Flux bootstrap (Terraform) points to the Kustomization resources in `kubernetes/clusters/${cluster}` named `${stage}.yaml`, making Flux recursively search `kubernetes/${stage}/${cluster}` for `kustomization.yaml`. Those files may contain additional patches to adapt the base configs to the cluster. They point to the base stage configs `kubernetes/${stage}/base/${namespace}/${app}` for each namespace containing apps to be deployed in this stage.

At the base of the base namespace config folder can be found a `namespace.yaml` file defining a Namespace resource, and a `kustomization.yaml` file referencing common components for the namespace `kubernetes/common/components`, the `transformers/` folder importing common transformers from `kubernetes/common/transformers` and `ks.yaml` files in each app folder of the namespace.

This `ks.yaml` file references each folder found in the app folder (usually only an `app` folder), which contains a `kustomization.yaml` referencing all files in the folder (`helmrelease.yaml`, `ocirepository.yaml`...).

Each stage depend on another one (`system -> platform -> core -> apps`) via `spec.dependsOn` field.

### Components

TODO

## Conventions

- Component READMEs stay with components (e.g., `kubernetes/apps/base/cilium/README.md`)
- Secrets from outside the platform are created , referenced via `external-secrets`
- Apps use `HelmRelease` via Flux, rarely raw manifests
- Clusters are mostly identical except for app selections and sizing, difference is made in `kubernetes/${stage}/${cluster}` `kustomization.yaml`
- **AI instructions**: `.agents/instructions/pr-review.instructions.md` is the live system prompt for the AI PR reviewer.

## Common Operations

- **Add app**: Create in `kubernetes/apps/${cluster}/` with kustomization + HelmRelease
- **Update app**: Merge renovate PR or manually edit and push
- **Troubleshoot**: Check `flux get all -n <namespace>`, `kubectl get events --sort-by=.lastTimestamp`
- **Scripts**: `scripts/` contains operational scripts. See `scripts/README.md` for the full list and usage.
- **Task operations**: The repo is driven by mise. Run `mise tasks` to see all commands. Common tasks:
  - `mise run context <cluster>` — switch Kubernetes context
  - `mise run backup <cluster>` — backup a target custer
  - `mise run restore <cluster>` — restore a target custer
  - `mise run upgrade providers production` — upgrade Terraform providers
  - `mise run upgrade k8s <cluster>` — upgrade Kubernetes version
  - `mise run upgrade talos <cluster>` — upgrade Talos version
  - `mise run krr` — run Kubernetes Resource Recommendations on current cluster
  - `mist run renovate` — run Renovate on local git repository
  - `mise run generate-uuid` — generate a UUIDv4 for authentik groups with python
  - `mise run devenv start / mise run devenv stop` — start/stop the development stack (local forgejo, zot...)
- **Tool management**: `mise.toml` manages required tools (e.g. `flate`, `talosctl`). Run `mise install` to set up the environment.
- **Validate locally**: Run `flate` before pushing GitOps changes:

    ```bash
    # Test Kustomizations + HelmReleases for a cluster
    # Always use "test" cluster
    flate test all --path ./kubernetes/clusters/test

    # Diff against a baseline (e.g., localdev branch)
    git worktree add --detach ./tmp/baseline origin/localdev
    flate diff ks --path ./kubernetes/clusters/test --path-orig ./tmp/baseline/kubernetes/clusters/test
    flate diff hr --path ./kubernetes/clusters/test --path-orig ./tmp/baseline/kubernetes/clusters/test
    git worktree remove ./tmp/baseline --force
    ```

## Documentation

- Main docs: `docs/`
- Component docs: README files co-located with components
- Terraform docs: `terraform/README.md`
- Personal notes: `docs/notes/`
- Decisions docs: `docs/decisions/`

## Adding Documentation

When adding architecture or operational docs, consider:

1. Put general docs in `docs/`
2. Keep component-specific docs with the component
3. Personal notes go in `docs/notes/`

## PR Review Standards

When reviewing Renovate PRs, enforce these criteria. Reviews may include konflate rendered-diff evidence (cluster impact, data-loss cautions, image changes). Treat blocker-level findings as high-priority signals.

### HelmRelease Requirements

- All applications MUST use `HelmRelease` via Flux, not raw manifests. In `${app}/resource/` folders, raw manifests are allowed.
- HelmReleases MUST use in priority `spec.chartRef` pointing to an `OCIRepository` with a pinned `ref.tag`. Some applications such as `llmkube` still use the legacy `spec.chart` pattern.
- Every app defines its own per-app `OCIRepository` in a dedicated `ocirepository.yaml` alongside the `HelmRelease`, named after the app, with `./ocirepository.yaml` listed in the app's `kustomization.yaml`. Do not put the `OCIRepository` inline in `helmrelease.yaml`, and do not rely on a shared/injected `OCIRepository`. For `app-template`-based apps, the `OCIRepository` component (`../../../common/components/repos/app-template`) must be imported in `components` of the `kustomization.yaml` at the root of the namespace directory.
- Must include `spec.interval` for reconciliation frequency
- Resource limits (CPU/memory) SHOULD be specified for production workloads, but this is not a hard requirement
- `valuesFrom` should reference ConfigMaps/Secrets, not inline values

### Namespace Convention

- `metadata.namespace` is **never** set inline on `HelmRelease` or `Kustomization` resources — this is intentional, not a violation
- The namespace is injected at build time by kustomize's `namespace:` directive in the per-app `kustomization.yaml` (e.g., `namespace: llm`)
- For Flux `Kustomization` resources, `spec.targetNamespace` is propagated automatically via the replacement component at `kubernetes/components/replacements/ks.yaml`
- Reviewers MUST NOT flag missing `metadata.namespace` on these resources as an issue

### Secret Management Rules

- **NEVER** commit plain-text secrets or credentials in Git
- All imported secrets MUST be set in FluxCD terraform bootstrap, which creates kubernetes secrets prefixed by `external-` in the `external-secrets` namespace. They can be sourced by `external-secrets` resources in other namespaces using the `external-secrets` `ClusterSecretStore`.
- If a PR introduces a new secret, verify it's external-secrets backed

### Image & Digest Policy

- Prefer `@sha256:` digests over version tags for reproducibility (container images only)
- OCI artifacts (e.g., Helm charts pulled via `OCIRepository`) are exempt: pin by tag/version, since they don't support SHA-tag references the same way container images do
- For tag-only updates, verify OCI metadata (revision/source/created)
- If revision changes between digests, ensure it's intentional
- Reject updates from untrusted registries (must be allowlisted)
- Preferred registries: GHCR.io, registry.k8s.io, Docker Hub (fallback)
- Avoid Docker Hub for critical infrastructure components

### Breaking Change Detection

Always `request_changes` if:

- API version changes (e.g., `apiVersion: apps/v1beta1` → `apps/v1`)
- Deprecated field usage introduced
- Major version bumps without justification
- CRD changes or custom resource modifications
- Network policy or security context relaxations

### Required Evidence for Approval

Before approving, verify:

1. Release notes/changelog mention the upgrade
2. GitHub compare shows expected changes
3. Version aligns with what Renovate reported
4. No breaking changes identified in release notes
5. Security advisories don't apply to this version

For Helm chart and container image upgrades, you **must** use tool requests (e.g., `gh_api`) to fetch release notes, changelogs, and upstream metadata from the source repository. Do not rely on the PR description alone — verify against the actual upstream release.

### Kubernetes ↔ Talos compatibility

This cluster runs on **Talos Linux**, which pins the node OS and the kubelet together. The deployed Talos version is the default value of the variable `talos_version` inside `terraform/k8s/nodes/variables.tf`. When a PR bumps the Kubernetes version (the kubelet image, a `KubernetesUpgrade` resource, or the `kubernetes` Renovate group), you MUST:

1. Read the deployed Talos version from `terraform/k8s/nodes/variables.tf`.
2. Confirm the new Kubernetes version is supported on that Talos release against Talos's published support matrix — search the web for "talos <version> kubernetes support matrix" (the docs live at `docs.siderolabs.com`; the old `talos.dev` matrix URLs 404) and fetch it.
3. Cite the matrix in the review. Do not approve a Kubernetes bump on "patch release" reasoning without confirming Talos supports it — an unchecked matrix is an Unknown, not an approval.

_Flux automatically reconciles changes once the PR is merged._
