# scripts/

Operational scripts for the cluster. One-shot helpers, not a library.

## llm_bench.py

A/B benchmark harness for the `qwen38` LLM service (stdlib only). Fixed
probes so runs are comparable across engine/kernel configs: short prose,
structured JSON x3 (with per-run spec-decode acceptance from `/metrics`),
a ~64K-token cold/warm context pair (unique salted filler so the cold run
is truly cold), a math probe (expect 70336) and a tool-call probe.

```bash
# let the script manage the port-forward
python3 scripts/llm_bench.py --port-forward

# or against an existing port-forward / any OpenAI-compatible endpoint
python3 scripts/llm_bench.py --base http://127.0.0.1:18080
python3 scripts/llm_bench.py --base http://127.0.0.1:18080 --skip-long --out /tmp/bench.jsonl
```

Exit 0 = all quality probes passed. Reference numbers for the current
vLLM MTP k=4 cutlass service are in `docs/notes/llm-journey.md`.
