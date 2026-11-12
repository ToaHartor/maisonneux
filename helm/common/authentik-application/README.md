# authentik-application

Vendored Helm chart, consumed in-repo by the `oidc-application` and
`proxy-application` kustomize components (the `${APP}-oidc` /
`${APP}-proxy` HelmReleases render it directly from this git tree via
`sourceRef: GitRepository/flux-system`).

## Provenance

Vendored from `https://codeberg.org/wrenix/helm-charts`, tag
`authentik-application-v0.4.9` (git commit `41c78683`, 2025-05-07),
matching the previously pinned OCI digest
`sha256:604e66bd73e3401eb06ac82288ac44ca004f72d927358135b9f4ac17d742df40`.

The codeberg OCI registry stopped serving anonymous pulls (2026-11),
so the chart was mirrored here instead. Re-sync by cloning the tag,
copying the chart back over this directory, and bumping
`Chart.yaml` version awareness in the consuming components if needed.
