#!/usr/bin/env python3
"""Seed every root-managed plugin into each named profile's own user
plugin dir.

Hermes resolves user plugins per-home: user_plugins_dir() is hard-coded
to $HERMES_HOME/plugins/, and a named profile re-homes HERMES_HOME to
/opt/data/profiles/<name>/. So a plugin the alpine init seeds only at
the root /opt/data/plugins/<p>/ (today the memini memory provider,
fetched from the eleboucher/memini-hermes mirror) is invisible to named
profiles — their configured memory.provider (set machine-wide by
hermes-machine-config) then fails with "configured but not installed and
not in the plugin catalog".

The alpine init runs as uid 1024 and before the ownership convergence,
so it cannot seed a brand-new (still root-owned) profile dir. This step
runs in the install-tools init container, as root, before the find-chown
convergence (which chowns the tree this step writes, exactly as it does
for the upsert/merge steps), so it reliably copies every healthy root
plugin into each existing profile's plugins dir in the same boot.

Semantics:
- A plugin is "healthy" when its root dir holds an __init__.py; a root
  dir without one is skipped (a partial/unhealthy fetch must not be
  propagated).
- A profile copy is re-seeded only when it is missing or its .ref marker
  differs from the root's (the alpine fetch writes .ref = the pinned
  SHA, so a bump propagates on the next boot; unchanged pins are a
  no-op).
- Profile dirs are never created here — only profiles that already
  exist are seeded (a fragment/plugin must not resurrect a deleted
  profile). Newly created plugin dirs land root-owned; the install-tools
  find-chown step (this container, runs immediately after) converges
  them to the 1024 convention, so this script does not chown.
- Fail-open: any write error logs a WARN and leaves that profile
  untouched; the gateway keeps its current (absent) plugin and the next
  boot retries. The script always exits 0 so the shell's `if ! ...`
  guard does not double-report.
"""
import os
import shutil

ROOT_PLUGINS = "/opt/data/plugins"
PROFILES_DIR = "/opt/data/profiles"


def _ref(path: str) -> str:
    """The .ref marker under *path* ("" when absent/unreadable)."""
    try:
        with open(os.path.join(path, ".ref"), encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return ""


def main() -> None:
    if not os.path.isdir(ROOT_PLUGINS):
        print(f"seed-plugins: {ROOT_PLUGINS} absent; nothing to seed")
        return
    plugins = sorted(
        p for p in os.listdir(ROOT_PLUGINS)
        if os.path.isdir(os.path.join(ROOT_PLUGINS, p))
        and os.path.isfile(os.path.join(ROOT_PLUGINS, p, "__init__.py"))
    )
    if not plugins:
        print(f"seed-plugins: no healthy plugins under {ROOT_PLUGINS}; "
              "nothing to seed")
        return
    if not os.path.isdir(PROFILES_DIR):
        print(f"seed-plugins: {PROFILES_DIR} absent; nothing to seed")
        return
    prof_dirs = sorted(
        os.path.join(PROFILES_DIR, d) for d in os.listdir(PROFILES_DIR)
        if os.path.isdir(os.path.join(PROFILES_DIR, d))
    )
    if not prof_dirs:
        print(f"seed-plugins: no profiles under {PROFILES_DIR}; "
              "nothing to seed")
        return

    for pdir in prof_dirs:
        pname = os.path.basename(pdir)
        dest_root = os.path.join(pdir, "plugins")
        for plugin in plugins:
            src = os.path.join(ROOT_PLUGINS, plugin)
            dst = os.path.join(dest_root, plugin)
            src_ref = _ref(src)
            # Already in sync with the root marker: skip the copy.
            if os.path.isdir(dst) and _ref(dst) == src_ref:
                continue
            try:
                if os.path.isdir(dst):
                    shutil.rmtree(dst, ignore_errors=True)
                shutil.copytree(src, dst)
                print(f"seed-plugins: seeded {plugin} into {pname}")
            except OSError as e:
                print(f"WARN: cannot seed {plugin} into {pname} "
                      f"({e}); skipped — converges on the next boot")


if __name__ == "__main__":
    main()
