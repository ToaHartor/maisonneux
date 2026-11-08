# hermes app — GitOps layout, config overlays, and profile management

Hermes agent (NousResearch) on the homelab cluster: one gateway process
multiplexes every profile (the `default` shell profile + named profiles such
as `operator` and `main`). Git is the source of truth for machine-level
settings; the PVC (`hermes-data`) holds profiles, sessions, and state, and
profile *creation* stays a deliberate hermes CLI/dashboard operation.

## Folder layout

```text
kubernetes/apps/base/ai/hermes/
├── ks.yaml                  # Flux Kustomization (targetNamespace ai)
└── app/
    ├── kustomization.yaml   # resources + configMapGenerator (this folder)
    ├── helmrelease.yaml     # app-template HelmRelease: pod, volumes, init flow
    ├── ocirepository.yaml   # app-template chart source
    ├── externalsecret.yaml  # hermes-dotenv ExternalSecret (litellm master key)
    ├── README.md
    └── resource/            # raw files → kustomize ConfigMaps
        ├── hermes-base-config/
        │   ├── AGENTS.md    # workspace instruction file
        │   └── config.yaml  # profile base config (per-profile values only)
        ├── hermes-machine-config/
        │   └── config.yaml  # machine-level managed overlay
        └── hermes-profile-config/
            ├── mise.toml           # boot-time tool pins (mise install, jdx/mise image)
            ├── apply-profiles.py   # driver: merges every <name>.yaml fragment via the mise-installed yq
            ├── upsert.py           # driver: upserts /run/dotenv keys into the .env files
            ├── operator.yaml       # fragment for the operator profile
            └── main.yaml          # fragment for the main profile
```

ConfigMap contents are **raw files** (plain YAML/Python/Markdown — no
YAML-in-YAML escaping). `kustomization.yaml` generates the ConfigMaps via
`configMapGenerator`, with `generatorOptions.disableNameSuffixHash: true`
so the names are exactly `hermes-base-config` / `hermes-machine-config` /
`hermes-profile-config` (the repo pattern from
`kubernetes/clusters/production/flux-system/kustomization.yaml`). The
HelmRelease no longer carries inline ConfigMap data — the chart's
`configMaps` value is empty and the app's Kustomization owns the
ConfigMaps, applied in the same transaction as the HelmRelease. The
base CM is named `hermes-base-config` (not `hermes-configmap`) so the
name has no history in any Helm release state: Helm rollbacks only
diff release-state names, so the old Helm-owned `hermes-configmap` can
no longer be resurrected or deleted by an upgrade/rollback loop.

## The overlay layers

Hermes has no native profile config inheritance, so machine settings are
split into layers that compose at boot:

| Layer | ConfigMap / Secret | Mount | Container | Semantics |
| ----- | ------------------ | ----- | --------- | --------- |
| profile base | `hermes-base-config` | `/run/config` | init | copied to `/opt/data/config.yaml` (default profile) and `/opt/data/workspace/AGENTS.md` on every boot — Git-pinned, reset each start |
| machine overlay | `hermes-machine-config` | `/etc/hermes/config.yaml` (subPath) | app (gateway) | hermes v0.22+ *managed scope*: deep-merged on top of **every** profile's config.yaml, managed values win per leaf; sibling keys stay user-controlled; a malformed file is logged and fails open (never blocks startup) |
| profile fragments | `hermes-profile-config` | `/run/profile-config` | install-tools | one `<name>.yaml` fragment per profile; `apply-profiles.py` deep-merges each fragment into `/opt/data/profiles/<name>/config.yaml` via the mise-installed `yq` (fragment wins per leaf, round-trip-validated before the write) |
| managed env | `hermes-dotenv` (Secret, ExternalSecret-owned) | `/run/dotenv` (install-tools) + `envFrom` on the app container | both | keys upserted by `upsert.py` into the profiles' `.env` files (managed keys are also write-protected in the dashboard by hermes' `env_write_refusal`); container-level env covers keys consumed as plain environment variables |

Design rules for what goes where:

- **Machine overlay** (`hermes-machine-config/config.yaml`): values that
  must be identical for all profiles and that users must not be able to
  shadow — providers, model, `mcp_servers`, terminal backend pin,
  security/privacy baselines. `${VAR}` references in it expand against
  the **process environment only**, so profiles cannot shadow them.
- **Per-profile fragments** (`hermes-profile-config/<name>.yaml`):
  genuinely divergent keys only (toolset trims, approvals policy, model
  overrides). Keys hermes resolves bypassing the overlay —
  `secrets.command`, `skills.external_dirs` — must live in the profile's
  own config, not the machine overlay.
- The machine overlay is mounted as a **subPath file mount**
  (`/etc/hermes/config.yaml`), never the whole directory: the image bakes
  `/etc/hermes/chromium-executable-path` (arch-specific staged chromium
  binary path), and a whole-directory mount would hide it and break the
  browser toolset probe.

## Substitution pipeline

The raw files use two placeholder styles, resolved in two passes (same
as every other app in `kubernetes/apps/base`):

1. **Pass 1** — the hermes Kustomization's `postBuild.substitute`
   (kustomize): `$${VAR}` collapses to `${VAR}` (kustomize's escape
   survives intact), and app/cluster-level variables declared in
   `ks.yaml` (`SUBDOMAIN`, `DOMAIN_WEBSECURE`, …) are substituted.
2. **Pass 2** — the stage Kustomization's `postBuild.substituteFrom` on
   the `general-config` ConfigMap resolves the remaining `${VAR}`.
   This pass runs **strict**: any `${VAR}` that is declared in neither
   pass aborts the Kustomization build (`BuildFailed: variable not
   set`), which blocks the whole hermes app (the 2026-11-08 incident —
   a shell loop variable in the init script broke the build and the
   Helm rollback loop then deleted `hermes-configmap`). Guardrail:
   no **shell** variables may reach the rendered text — shell loops in
   init commands are forbidden, that logic lives in the
   `hermes-profile-config` scripts instead. Undeclared application
   placeholders like `${LITELLM_API_KEY}` survive the passes by design
   and are expanded by hermes at runtime.
   `LITELLM_API_KEY` is intentionally in **no pass**: the rendered
   placeholder `${LITELLM_API_KEY}` (from `$${LITELLM_API_KEY}` in the
   raw file) survives both passes and is expanded at runtime by hermes'
   config loader against the profile's `.env` (populated from the
   `hermes-dotenv` secret by the init `upsert.py`) or the process
   environment for the default profile — the key itself is never held in
   Git or in `general-config`.

## Init flow

`initContainers` run in this order (see `helmrelease.yaml`):

1. **copy-agent-source** (hermes image): copies `/opt/hermes` to
   `/agent-src` and runs `docker_config_migrate.py` for the launch-scope
   config (`/opt/data/config.yaml`).
2. **init** (alpine — plain file work only; the pod runs as uid 1024,
   so the alpine container cannot `apk`-install anything):
   1. copies `/run/config/config.yaml` → `/opt/data/config.yaml` and
      `AGENTS.md` → `/opt/data/workspace/AGENTS.md` (the default
      profile's Git-pinned base);
   2. fetches the pinned memini plugin release (guarded by a `.ref`
      marker — offline on normal restarts).
3. **install-tools** (hermes image — the alpine init can't run the
   scripts: uid 1024 means no `apk` and no python; install-tools
   itself overrides to `runAsUser: 0` — see step 4):
   1. runs `mise install` with the CM-pinned tool manifest
      (`MISE_CONFIG_FILE=/run/profile-config/mise.toml`, binary from
      the jdx/mise image mount `/opt/mise`; `XDG_CACHE_HOME` pins the
      sigstore TUF trust-root cache used by cosign signature
      verification onto the shared PVC — the hermes image's `$HOME`
      is not writable by uid 1024, so the default
      `$HOME/.cache/sigstore-rust` path would fail with permission
      denied): tools land in the
      shared PVC (`MISE_DATA_DIR=/opt/data/.local/share/mise`) with
      shims in `/opt/data/.local/share/mise/shims` — already on the
      agent's PATH, so agents pick these tools up for free too.
      First boot downloads from GitHub; later boots are offline
      (PVC-cached, mise skips tools whose installed version matches
      the pin). Non-fatal: a failed download only skips the
      fragment merge this boot (the next boot retries);
   2. runs `upsert.py`: upserts managed `.env` keys (from `/run/dotenv`)
      into the launch-scope `/opt/data/.env` and the `.env` of **every
      existing profile directory** (glob + existing-dir guard — new
      profiles are covered automatically on the next start, deleted
      profiles are never resurrected) — replace-or-append per key,
      user-managed lines survive;
   3. runs `apply-profiles.py`: merges the Git-managed profile
      fragments with the mise-installed `yq` (the driver resolves the
      installed binary through mise's `latest` symlink, falling back
      to the shim — the direct binary skips mise's CWD-dependent
      config/trust layer) — for each
      `/run/profile-config/*.yaml` it deep-merges the fragment into
      `/opt/data/profiles/<name>/config.yaml` when the profile
      directory exists (fragment wins per leaf, lists replaced, yq's
      round-trip emitter keeps comments/quotes/untouched scalars),
      seeds a fresh config from the fragment when the profile has
      none yet, and logs a WARN and skips when the profile directory
      does not exist (a fragment may safely exist ahead of the
      profile).
      All loop/glob logic lives in these ConfigMap scripts on purpose:
      the rendered manifest must not contain shell variables — Flux'
      pass-2 envsubst (strict) would abort the Kustomization build on
      any undeclared `${VAR}`. The mise install step follows the same
      rule (an env-var *prefix* assignment, no shell variables at
      all). The find-chown step is shell-free as well: a bare
      `find`/`chown` with no `$`-references anywhere.
   4. converges ownership: `find /opt/data ! -user 1024 -exec
      chown 1024:1024 {} +` — the hermes image's s6 root layer
      (stage2 hook, root terminal service slots) and the 10000-era
      hermes user leave files under /opt/data owned by uids other
      than 1024 (e.g. `profiles/<name>/.env`, `state.db`, the mise
      shims directory) that the uid-1024 supervised gateway
      (s6-setuidgid + `HERMES_UID` drop) cannot read or write; the
      image's own stage2 chown only fixes the top-level directory,
      so this step is what corrects the rest. Runs last so it also
      converges the files the steps above just wrote as root.
      Idempotent (fully-1024 volume = no-op), non-fatal (WARN +
      continue).

## Tool pinning (mise)

The pod's boot-time tools are pinned in the `mise.toml` key of the
`hermes-profile-config` ConfigMap (currently `yq = "4.54.2"`, the
profile-fragment merger). The install-tools init container runs
`mise install` with that file as config (the jdx/mise image mount
provides the mise binary; `MISE_*` env vars on the container point
mise at the shared PVC so installs persist and the agent's PATH
already includes the shims directory; `XDG_CACHE_HOME` on both the
init and app containers pins the sigstore/cosign TUF trust-root
cache onto the same PVC — without it, cosign's verification step
fails with `Permission denied` creating the default
`$HOME/.cache/sigstore-rust` directory, because the hermes image's
`$HOME` is not writable by uid 1024). `apply-profiles.py` resolves
yq through the version-agnostic `installs/yq/latest/yq` symlink
that mise maintains, with the shim as fallback (the shim re-runs
mise's config/trust layer, which is CWD-dependent and the init
container's CWD is the image's WORKDIR). To bump a tool or add one:
edit the CM key only — the next boot re-downloads just the changed
tool, no HelmRelease edit. yq is used instead of a Python YAML
module because the sealed hermes venv ships no standalone yaml
library (hermes itself parses YAML through its own `hermes_yaml`,
ruamel-backed, YAML 1.1 policy); yq's `ea` deep merge gives
fragment-wins-per-leaf with list replacement, and its round-trip
emitter preserves the user's comments, quotes, and untouched
scalars (YAML 1.1 booleans like `y`/`n` survive verbatim).

The gateway's 30-second rescan serves any valid new profile directory
without a pod restart; parking/unparking a profile is `hermes -p
<name> gateway stop` / `start` (writes/removes the `gateway.parked`
marker — only meaningful for named profiles, never `default`).

## Per-profile instructions (SOUL.md)

Per-profile identity/instructions live in **`SOUL.md` in the profile's
own home** — `/opt/data/SOUL.md` (default) or
`/opt/data/profiles/<name>/SOUL.md` (named profiles). Unlike
`AGENTS.md` (shared by all profiles via the pinned
`/opt/data/workspace` cwd), `SOUL.md` is natively per-profile and is
**self-maintained**: each profile evolves its own `SOUL.md` with its
file tools over time.

Properties that make this work safely:

- **Not reset on boot** — the init container only touches
  `config.yaml` / `AGENTS.md` / `.env`; agent edits to `SOUL.md`
  survive restarts and image bumps (PVC-persisted).
- **Cross-profile writes are blocked** (upstream home guard): a
  profile can only modify its own `SOUL.md`, never another profile's.
- **Own-home writes are gated by the profile's `approvals:` policy**
  (the home-write guard — the project-local protected-instruction gate
  exempts the agent's own HERMES home):
  - `main` (`smart`) → self-edits are auto-approved or prompted per
    heuristic;
  - `operator` (`smart` + `cron_mode: deny` + a monitoring-only
    `smart_policy` rule) → routine self-edits to its own `SOUL.md`
    pass the guardian automatically; mutative commands escalate and
    unattended cron stays hard-blocked.
- Seed an initial baseline **once** per profile (dashboard file tool,
  or before `hermes profile create <name> --clone-from default`, which
  copies the home). Do **not** wire an init-time `SOUL.md` copy — an
  unconditional seed copy would squash agent edits on every boot.

## How to add a profile

1. **Create the profile** (deliberate operation, not Git): in the
   dashboard, or via the gateway CLI
   `hermes profile create <name> --clone-from default` (a clone carries
   over sessions, state.db, memories and skills; create without a clone
   for a fresh profile). The profile appears in the dashboard picker on
   the next 30-second rescan.
2. **Add the fragment**: create
   `resource/hermes-profile-config/<name>.yaml` containing only the
   per-profile keys (copy `main.yaml` / `operator.yaml` as examples),
   and add one line to the `hermes-profile-config` generator's `files:`
   list in `kustomization.yaml`. An empty fragment is a silent no-op, so
   the fragment can land before the profile itself.
3. **Managed env keys**: nothing to do — the init `upsert.py`
   covers the launch-scope `/opt/data/.env` plus the `.env` of every
   existing profile directory, so a profile that resolves `${VAR}`
   references (e.g. the `mcp_servers` bearer header) picks up the
   machine keys automatically on the next start.
4. **Commit + push**. On the next pod start (or rollout) the init merge
   loop applies the fragment into `/opt/data/profiles/<name>/config.yaml`;
   the gateway serves it on its next rescan. Optionally park it with
   `hermes -p <name> gateway stop` for a deliberate activation.

Fragments are re-merged on **every** boot (the profile's config.yaml is
rebuilt as base ← fragment, and the base is whatever the profile's own
config.yaml already contains — dashboard edits to keys the fragment does
not manage survive; keys the fragment manages are Git-pinned and win).

## Verification

```bash
# full render test (Kustomization + HelmRelease + schema)
flate test all --path ./kubernetes/clusters/test

# confirm the generated ConfigMap names/keys (offline, no hash suffix)
kubectl kustomize kubernetes/apps/base/ai/hermes/app \
  | grep -E "^kind: ConfigMap" -A1

# after a rollout: init merge loop + profile state
kubectl logs -n ai -l app.kubernetes.io/name=hermes -c init --tail=50
```
