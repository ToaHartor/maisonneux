#!/usr/bin/env python3
"""Driver: merge every Git-managed profile fragment into the
profile's config.yaml, using the yq binary installed by the
install-tools init container's `mise install` step (pin lives in
the hermes-profile-config ConfigMap's mise.toml). yq resolution:
the `latest` symlink in mise's installs tree (maintained by mise
itself across version bumps, so no version is hard-coded here),
falling back to the mise shim — the installed binary is preferred
because the shim re-runs mise's config/trust layer, which is
CWD-dependent (an untrusted project mise.toml in the CWD tree
makes the shim hard-error, and the init container's CWD is the
image's WORKDIR).

For each /run/profile-config/<name>.yaml fragment:
- no yq found (mise install failed this boot) -> WARN + skip the
  whole merge (fail-open: profiles keep their current config; the
  next boot retries);
- profile directory missing -> WARN + skip (a fragment may exist
  ahead of the profile itself; profile creation stays a deliberate
  hermes profile CLI / dashboard operation);
- fragment missing/empty -> no-op (yq's merge of an empty doc is
  identity, but we skip the work);
- no config.yaml yet -> the fragment becomes the whole config
  (fresh profile, e.g. right after `hermes profile create`);
- write failure (profile dir/files owned by a uid this container
  cannot write — root s6-layer or 10000-era files) -> WARN + skip
  that profile (fail-open: the gateway keeps its current config;
  the next boot retries once ownership has converged);
- otherwise -> deep merge via `yq ea '. *= load(<frag>)'`:
  fragment wins per leaf, nested maps merge recursively, lists
  are replaced (not concatenated), and yq's round-trip emitter
  keeps the user's comments/quotes and untouched scalars
  (YAML 1.1 booleans survive verbatim) — the same policy hermes
  uses when it writes these files.

The merge result is emitted to stdout, re-parsed by yq before
the write (never leave an unparseable config.yaml on disk), and
written atomically (.new + os.replace, mode 0600). Only
config.yaml is ever touched; profile directories are never
created or removed here. yq subprocess failures carry the yq
stderr in the message so a bad boot is diagnosable from the
init logs without re-running the merge by hand."""
import os
import pathlib
import re
import subprocess
import sys

FRAG_DIR = pathlib.Path("/run/profile-config")
PROFILES_DIR = pathlib.Path("/opt/data/profiles")
# Installed binary first (see module docstring), shim as fallback.
YQ_CANDIDATES = (
    "/opt/data/.local/share/mise/installs/yq/latest/yq",
    "/opt/data/.local/share/mise/shims/yq",
)
MAP_TAGS = {"!!map", "!!null"}


def fail(msg: str):
    raise SystemExit(msg)


def yq(*args, input_text=None):
    r = subprocess.run(
        [YQ, *args],
        input=input_text,
        capture_output=True,
        text=True,
        cwd="/")  # neutral CWD: never hand the tool a project tree
    if r.returncode != 0:
        detail = r.stderr.strip() or r.stdout.strip()
        fail(f"ERROR: yq {' '.join(str(a) for a in args)} "
             f"exited {r.returncode}: {detail[:400]}")
    return r


def main():
    global YQ
    YQ = next((p for p in YQ_CANDIDATES if os.path.exists(p)), None)
    if YQ is None:
        print("WARN: no yq under /opt/data/.local/share/mise "
              "(mise install failed this boot); profile-fragment merge skipped")
        return
    frags = sorted(FRAG_DIR.glob("*.yaml"))
    if not frags:
        print("no profile fragments found; nothing to merge")
        return
    for frag in frags:
        prof = re.sub(r"\.yaml$", "", frag.name)
        pdir = PROFILES_DIR / prof
        if not pdir.is_dir():
            print(f"WARN: profile fragment '{prof}' has no profile dir yet; skipped")
            continue
        if not frag.exists() or not frag.read_text().strip():
            print(f"{prof}: fragment is empty; nothing to merge")
            continue
        target = pdir / "config.yaml"
        try:
            if not target.exists():
                # Fresh profile (e.g. just cloned/created): the fragment
                # becomes the whole config.
                target.write_text(frag.read_text())
                os.chmod(target, 0o600)
                print(f"{prof}: fragment seeded as fresh config at {target}")
                continue
            tag = yq("-r", "tag", str(frag)).stdout.strip()
            if tag not in MAP_TAGS:
                fail(f"ERROR: {prof} fragment is not a mapping (tag {tag})")
            # yq string literals are double-quoted; the path never contains one.
            merged = yq("ea", f'. *= load("{frag}")', str(target)).stdout
            yq("-r", "tag", input_text=merged)  # round-trip: parse the merge result
            tmp = target.with_name(target.name + ".new")
            tmp.write_text(merged)
            os.chmod(tmp, 0o600)
            tmp.replace(target)
        except OSError as e:
            # The profile dir or its files are owned by a uid this
            # container cannot write (the hermes image's s6 root layer
            # or the 10000-era user can both leave files the 1024
            # convention does not own). Skip instead of crashing the
            # boot: the gateway keeps its current config and the next
            # boot retries once ownership has converged (the
            # install-tools find-chown step, or a host-side chown).
            print(f"WARN: cannot write {target} ({e}); "
                  f"merge skipped — ownership converges on the next boot")
            continue
        print(f"{prof}: fragment merged into {target}")


if __name__ == "__main__":
    main()
