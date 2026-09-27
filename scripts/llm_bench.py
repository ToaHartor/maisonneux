#!/usr/bin/env python3
"""qwen38 LLM A/B benchmark harness (stdlib only).

Runs the recorded probe suite against the live qwen38 service and prints a
summary table. Used for kernel/engine A/Bs (e.g. the b12x NVFP4 GEMM test
2026-09-28, see docs/notes/llm-journey.md and qwen38-vllm.yaml).

Probes (fixed content so runs are comparable across configs):
  1. short prose      400-word essay, 512 tokens, temp 1.0
  2. structured JSON  400-object array, 3000-token cap, temp 0, x3 runs
                      (temp 0 + same content -> deterministic; the x3 is a
                      stability check, not a sample)
  3. 59K context      ~64K-token filler prefix, cold then warm (prefix
                      cache) - the filler text is unique per RUN (random
                      salt) so a cold run is truly cold; compare against
                      the recorded baselines, not across runs
  4. math probe       sum of three-digit multiples of 7 -> expect 70336
  5. tool call        get_weather(Lisbon, celsius) via the qwen3_xml parser

Also reads the spec-decode Prometheus counters (/metrics) before/after the
structured runs to get per-run acceptance length.

Usage:
  # against an already-running port-forward
  python3 scripts/llm_bench.py --base http://127.0.0.1:18080

  # let the script manage the port-forward itself
  python3 scripts/llm_bench.py --port-forward

  # skip the ~35 s 59K pair when you only care about decode speed
  python3 scripts/llm_bench.py --port-forward --skip-long

Exit code: 0 = all quality probes passed, 1 = a probe failed or the service
was unreachable.
"""

import argparse
import json
import os
import secrets
import subprocess
import sys
import time
import urllib.request

DEFAULT_BASE = "http://127.0.0.1:18080"
DEFAULT_MODEL = "qwen38_27B"

MATH_ANSWER = "70336"  # sum of three-digit multiples of 7

FILLER_TEMPLATES = (
    "Meanwhile the velero backup schedule ran its nightly backup of every persistent volume in the "
    "cluster while barman streamed the postgres logical dumps to the s3 bucket and the zot registry "
    "pruned the stale oci tags from the helm chart mirror after the renovate bot opened its weekly "
    "digest of image updates against the two consumer blackwell nodes. ",
    "At the same time the litellm proxy rewrote its routing table for the karaseek agent while the "
    "forgejo action runner checked out the monorepo and flate rendered the kustomization overlays for "
    "the staging cluster before the flux source sync pulled the new helm releases down the wire. ",
    "In the background the true nas share was scrubbed by the scheduled task while the opnsense "
    "firewall pushed its new ruleset and the mikrotik switch renegotiated its bgp sessions with the "
    "two talos control plane nodes after the nightly certificate rotation finished without errors. ",
)


def http_json(url, payload=None, timeout=900):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST" if payload is not None else "GET",
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def chat(base, model, payload):
    t0 = time.perf_counter()
    out = http_json(base + "/v1/chat/completions", {"model": model, **payload})
    return out, time.perf_counter() - t0


def metric_values(base, names):
    with urllib.request.urlopen(base + "/metrics", timeout=30) as r:
        txt = r.read().decode()
    out = {n: 0.0 for n in names}
    for line in txt.splitlines():
        for n in names:
            if line.startswith(n + "{") or line.startswith(n + " "):
                p = line.rsplit(" ", 1)
                if len(p) == 2 and p[1].replace(".", "").isdigit():
                    out[n] += float(p[1])
    return out


def filler_prefix():
    """Unique ~64K-token prefix per run so the 'cold' probe is truly cold."""
    para = secrets.choice(FILLER_TEMPLATES) + f"[run-{secrets.token_hex(4)}] "
    return (para * 965) + "\n\nQuestion: how many times does the word 'velero' appear in the text above?"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default=os.environ.get("LLM_BENCH_BASE", DEFAULT_BASE))
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--skip-long", action="store_true", help="skip the 59K cold/warm pair")
    ap.add_argument("--port-forward", action="store_true",
                    help="start/stop kubectl -n ai port-forward svc/qwen38 for --base's port")
    ap.add_argument("--out", default=None, help="also dump raw responses to this path (.jsonl)")
    args = ap.parse_args()

    pf = None
    if args.port_forward:
        port = args.base.rsplit(":", 1)[-1]
        pf = subprocess.Popen(
            ["kubectl", "-n", "ai", "port-forward", "svc/qwen38", f"{port}:8080"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(3)

    dump = open(args.out, "w") if args.out else None
    failures = []

    def record(name, payload, data):
        if dump:
            dump.write(json.dumps({"probe": name, "payload": payload, "response": data}) + "\n")
            dump.flush()

    try:
        # 0. health
        models = http_json(args.base + "/v1/models")
        print(f"service: {args.base} model={args.model} (in /v1/models: "
              f"{any(m.get('id') == args.model for m in models.get('data', []))})")

        # 1. short prose
        p = {"messages": [{"role": "user", "content":
            "Write a 400-word essay about why home-grown Kubernetes clusters are a surprisingly "
            "practical way to learn production engineering. Be concrete."}],
            "max_tokens": 512, "temperature": 1.0}
        d, t = chat(args.base, args.model, p)
        record("short_prose", p, d)
        ct, pt = d["usage"]["completion_tokens"], d["usage"]["prompt_tokens"]
        print(f"short prose: {ct} tok in {t:.2f}s -> {ct/t:.1f} t/s "
              f"(finish={d['choices'][0]['finish_reason']})")

        # 2. structured JSON x3 with spec-decode deltas
        p = {"messages": [{"role": "user", "content":
            'Generate a JSON array of 400 objects describing fictional cities. '
            'Each object: {"name": string, "population": integer, "founded": integer year, '
            '"known_for": string (max 6 words)}. No markdown, raw JSON only.'}],
            "max_tokens": 3000, "temperature": 0}
        names = ["vllm:spec_decode_num_drafts_total",
                 "vllm:spec_decode_num_accepted_tokens_per_pos_total"]
        for i in range(3):
            pre = metric_values(args.base, names)
            d, t = chat(args.base, args.model, p)
            record(f"json_run{i+1}", p, d)
            post = metric_values(args.base, names)
            drafts = post[names[0]] - pre[names[0]]
            acc = post[names[1]] - pre[names[1]]
            ct = d["usage"]["completion_tokens"]
            print(f"json run{i+1}: {ct} tok in {t:.2f}s -> {ct/t:.1f} t/s "
                  f"(finish={d['choices'][0]['finish_reason']}, accept_len={acc/drafts:.2f})")

        # 3. 59K cold/warm
        if not args.skip_long:
            prefix = filler_prefix()
            p = {"messages": [{"role": "user", "content": prefix}],
                 "max_tokens": 128, "temperature": 0}
            d, t = chat(args.base, args.model, p)
            record("long_cold", {"content_len": len(prefix)}, d)
            print(f"long COLD: {d['usage']['prompt_tokens']} tok prefill in {t:.2f}s")
            p = {"messages": [{"role": "user", "content": prefix + " And what is the second word of the text?"}],
                 "max_tokens": 128, "temperature": 0}
            d, t = chat(args.base, args.model, p)
            record("long_warm", {"content_len": len(prefix)}, d)
            print(f"long WARM: {d['usage']['prompt_tokens']} tok in {t:.2f}s wall "
                  f"(prefix cache + {d['usage']['completion_tokens']} completion)")

        # 4. math probe
        p = {"messages": [{"role": "user", "content":
            "What is the sum of all three-digit multiples of 7? Show your working, "
            "then give the final number on its own line."}],
            "max_tokens": 1024, "temperature": 0}
        d, t = chat(args.base, args.model, p)
        record("math", p, d)
        ok = MATH_ANSWER in d["choices"][0]["message"].get("content", "")
        print(f"math probe: {'PASS' if ok else 'FAIL'} (expect {MATH_ANSWER}) in {t:.2f}s")
        if not ok:
            failures.append("math")

        # 5. tool-call probe
        p = {"messages": [{"role": "user", "content":
            "What's the weather in Lisbon right now? I prefer Celsius."}],
            "max_tokens": 256, "temperature": 0,
            "tools": [{"type": "function", "function": {
                "name": "get_weather",
                "description": "Get current weather for a city.",
                "parameters": {"type": "object", "properties": {
                    "city": {"type": "string"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}},
                    "required": ["city"]}}},
            ]}
        d, t = chat(args.base, args.model, p)
        record("tool_call", p, d)
        tc = d["choices"][0]["message"].get("tool_calls")
        ok = bool(tc) and "Lisbon" in json.dumps(tc[0]["function"]["arguments"])
        print(f"tool call: {'PASS' if ok else 'FAIL'} "
              f"({json.dumps(tc[0]['function']['arguments'])[:100] if tc else 'no tool_calls'})")
        if not ok:
            failures.append("tool_call")

        print("\nverdict: " + ("ALL PROBS PASS" if not failures else f"FAILED: {failures}"))
    finally:
        if pf:
            pf.terminate()
        if dump:
            dump.close()
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
