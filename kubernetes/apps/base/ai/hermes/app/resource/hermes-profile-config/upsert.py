#!/usr/bin/env python3
"""Upsert the managed .env keys into the launch-scope .env file and every
existing profile's .env.

The keys live in the hermes-dotenv secret (owned by the hermes-dotenv
ExternalSecret, sourced from the litellm master key; see
externalsecret.yaml) and are mounted read-only at /run/dotenv: one file
per key, filename = key, content = value. The gateway multiplexes all
profiles in one process, and hermes resolves variable references in
config.yaml (mcp_servers headers, providers key_env) from the profile's
.env secret scope instead of the container environment — without
LITELLM_API_KEY there the profile sends the literal Bearer placeholder
and litellm answers 401, parking the MCP server.

The upsert replaces a managed key's line or appends it; user-managed
.env lines survive. The target list is the launch-scope /opt/data/.env
plus the .env of every existing profile directory, so new profiles pick
the keys up automatically on the next start. Profile directories are
never created here (a deleted profile must not be resurrected by its
.env).
"""
import glob
import os

DOTENV_DIR = "/run/dotenv"
LAUNCH_ENV = "/opt/data/.env"
PROFILES_GLOB = "/opt/data/profiles/*/"


def main() -> None:
    targets = [LAUNCH_ENV]
    for pdir in sorted(glob.glob(PROFILES_GLOB)):
        if os.path.isdir(pdir):
            targets.append(pdir.rstrip("/") + "/.env")

    for dotkey in sorted(glob.glob(os.path.join(DOTENV_DIR, "*"))):
        if not os.path.isfile(dotkey):
            continue
        key = os.path.basename(dotkey)
        with open(dotkey, encoding="utf-8") as fh:
            val = fh.read().strip()
        if not val:
            continue
        prefix = key + "="
        for envfile in targets:
            if not os.path.isdir(os.path.dirname(envfile)):
                # /opt/data always exists; a profile .env is only
                # touched when its profile directory exists — profile
                # directories are never created here.
                continue
            lines = []
            if os.path.exists(envfile):
                try:
                    with open(envfile, encoding="utf-8") as fh:
                        lines = [
                            l for l in fh.read().splitlines()
                            if not l.startswith(prefix)
                        ]
                except PermissionError:
                    # The file exists but this uid cannot read it
                    # (e.g. a profile created outside the pod's uid 1024
                    # ownership). Skip it instead of failing the boot:
                    # the gateway (same uid) cannot read it either, so
                    # the profile will 401 on MCP headers until the
                    # ownership is fixed from the host:
                    #   kubectl exec -n ai <hermes-pod> -- chown 1024:1024
                    #     /opt/data/profiles/<name>/.env
                    # The next boot re-runs the upsert and converges.
                    print(f"WARN: cannot read {envfile} (permission denied); "
                          "upsert skipped — fix ownership (chown 1024:1024) "
                          "from the host, next boot converges")
                    continue
            lines.append(f"{key}={val}")
            try:
                tmp = envfile + ".new"
                with open(tmp, "w", encoding="utf-8") as fh:
                    fh.write("\n".join(lines) + "\n")
                os.chmod(tmp, 0o600)
                os.replace(tmp, envfile)
            except OSError as e:
                print(f"WARN: cannot write {envfile} ({e}); upsert skipped")
                continue
            print(f"upserted {key} into {envfile}")


if __name__ == "__main__":
    main()
