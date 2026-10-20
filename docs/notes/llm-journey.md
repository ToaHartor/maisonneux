# LLM journey: Qwen 3.8 27B on 2× RTX 5060 Ti (2026-09)

(Revision with Qwen 3.8 27B)

> Decision record: `docs/decisions/2026-09-28-llm-journey.md` (ADR). This log keeps the
> full A/B evidence trail behind that decision.

The full optimization journey for the agentic LLM service: DFlash2 drafter
(✗ long context) → embedded MTP head → rejected tuning levers → quant A/B
(esatapedico MID-HIGH) → and the 2026-09-26 decision to move off llama.cpp
entirely.

## End state & conclusion (2026-09-28, after the final A/B suite; 2026-10-19:
vLLM 0.32.0 + NVFP4 KV live)

The `qwen38` InferenceService runs **vLLM 0.32.0 (b12x NVFP4 GEMM + XQA
decode) + embedded MTP k=4 + NVFP4 KV** on the revision-pinned gittensor
NVFP4 checkpoint, TP2 over the two RTX 5060 Ti 16 GB. Beellama MTP
(MID-HIGH NVFP4) is the kept fallback; everything else is shelved or
parked.

**Settled config** (all A/B'd on this box, verdicts in the sections below
and in the `qwen38-vllm.yaml` header):

| Knob             | Value                | Why                                                                  |
| ---------------- | -------------------- | -------------------------------------------------------------------- |
| Kernel           | `flashinfer_b12x`    | +15% structured vs cutlass (accept 2.64 vs 2.32), ties elsewhere     |
| Spec decode      | MTP k=4              | k=6 tested & loses (per-draft-step cost > acceptance gain)           |
| Cudagraphs       | `PIECEWISE`          | FULL_AND_PIECEWISE re-tested, no t/s conversion, -3.2K pool          |
| KV cache         | `nvfp4`              | A/B'd 10-19: 1.87x pool at -19%/-30% t/s, quality PASS       |
| Prefill          | chunked, 4096 chunks | 8192 measured: no gain, caps ctx at 200K                             |
| GPU mem util     | 0.95                 | measured safe limit; 0.97 = crash margin for +5K tokens we don't use |
| Async scheduling | ON (auto)            | verified default in v0.30.0 for MTP; no flag in this build           |
| Pool             | 488,973 tok          | 1.87x of the 262,144 requirement (was 279,726 / 1.07x on fp8)        |

**Final ranking on this box (same-day paired benches, zero concurrency):**

| Candidate                      | Short prose  | Structured                  | Verdict                                    |
| ------------------------------ | ------------ | --------------------------- | ------------------------------------------ |
| vLLM b12x MTP k=4 (PRIMARY)    | 66.3 t/s     | 108.1 t/s (acc 2.64)        | **running**                                |
| vLLM cutlass MTP k=4           | 66.3 t/s tie | 94.0 t/s (acc 2.32)         | loses on structured                        |
| vLLM MTP k=6                   | 59.0 t/s     | 84-85 t/s                   | per-step cost kills deep k                 |
| beellama MTP k=3 MID-HIGH      | 52-57 t/s    | 85 t/s                      | **fallback endgame**                       |
| DSpark-beellama (layer split)  | 34.1 t/s     | 45 t/s                      | 2x PCIe allreduce penalty; shelved         |
| DSpark-beellama (tensor split) | —            | —                           | upstream crash (#27819 class, #27858 open) |
| SGLang MTP/EAGLE               | —            | pool clamps ~90K            | SHELVED (#36010)                           |
| DSpark drafter on vLLM         | —            | pool -113K, draft load fail | parked                                     |

**What the week of tests taught (reusable):**

- Prompt content dominates structured t/s - A/Bs must pin the prompt
  (`scripts/llm_bench.py` does; the 123-vs-108 t/s scare was a confound).
- Deep-k acceptance gains don't beat per-step draft cost on a
  PCIe-only 2-GPU box: k=6 lost on both axes despite a healthy acceptance
  curve. Same non-transfer class as beellama's nDraftMax 8.
- Full cudagraphs (+2.4% steps/s) don't convert to tok/s here.
- Day-to-day GPU clock drift is the biggest noise source - paired
  same-day A/Bs only; cross-day comparisons are suggestive at best.
- Hardware-bound numbers from recipe cards (H200/GB300, 5090) don't
  transfer to 5060 Ti - always re-measure.

**Open items, each with its trigger:** 0.32.0+fp8 isolation bench ->
pin the NVFP4-specific t/s delta (the 10-19 run is confounded by the
0.30->0.32 engine bump) · FLASHINFER fused multi-step draft
(#55292/#57443/#54369) -> re-A/B k=6/8 · llama.cpp #27858 merged into a
beellama release -> DSpark-bee tensor-split retry (template ready) ·
vLLM image bumps -> re-verify b12x + k. Marginal contingency levers:
gpuMemUtil 0.97 (only when a test becomes pool-bound), node-level GPU
clock lock (consistency). The hard ceiling is KV bandwidth at depth -
NVFP4 KV (landed + kept 10-19) bought the pool; the at-depth decay is
now the thing to watch on real traffic.

## Why vLLM won

The trigger was the skrodahl recipe, measured on **identical hardware**
(2× 5060 Ti, TP2, stock vLLM 0.30.0):
<https://github.com/skrodahl/qwen38-27B-dual-rtx5060>

A/B on this cluster (vLLM live vs recorded beellama baselines, same
prompts):

| Test                             | beellama                   | vLLM                                                      | Δ                                               |
| -------------------------------- | -------------------------- | --------------------------------------------------------- | ----------------------------------------------- |
| Short prose (~500 tok, temp 1.0) | 60.6-62.8 t/s              | ~72 t/s                                                   | +15-18%                                         |
| 59K prefill, cold                | ~44 s (1,336 t/s)          | ~21 s                                                     | ~2×                                             |
| 59K prefill, warm                | re-prefilled every request | **~1.5 s** (prefix cache)                                 | the whole point                                 |
| 59K full request wall            | ~48 s                      | **4.1 s** (run 2)                                         | ~12×                                            |
| Structured JSON                  | ~61-65 t/s                 | **123 t/s**                                               | ~2× (reproduces the recipe's 124.9 within 1.5%) |
| Quality probes                   | —                          | math ✓ (70336, clean CoT), tool call ✓ (qwen3_xml parser) | pass                                            |

The two big wins are content-class dependent, and both are exactly the
agentic profile:

1. **Prefix caching.** beellama ran `--cache-ram 0`, so every request
   re-prefilled the 20-60K system/agent prefix (~30-45 s each). vLLM's
   `--enable-prefix-caching` + chunked prefill makes the second request on
   a conversation nearly free. At 59K context this turned a ~48 s request
   into a ~4 s one.
2. **Structured output.** MTP acceptance on JSON/tool-calls reaches
   4.3-5.7 tokens/step (vs ~2.7 on prose), so predictable output decodes
   at ~2×. Agent turns are full of it.
3. Plain prose only gains 15-18% (vLLM 72 t/s vs beellama 61-65; the
   recipe's 78 t/s is the greedy/sampling-bound upper edge).

Decode math (from the recipe, confirmed by our logs):
`tok/s = steps/s × acceptance`, `step time = 25.4 ms + 2.37 ms × k` at
depth 0 (+35% per-position cost at 131K as the KV cache grows). k=4 is
the prose/mixed peak; k=5-7 only helps overwhelmingly-structured output.
At 59K depth our measured acceptance: mean len 2.5-3.5, per-pos
(0.69, 0.47, 0.37, 0.30) — matching the recipe's depth tables.

## The journey that got here (context for future tuning)

All beellama-side experiments (v0.4.7, 2× 5060 Ti tensor split):

- **DFlash2 drafter: abandoned.** 108.7 t/s / 91% acceptance at short
  context, but the drafter only sees a 2048-token sliding window of target
  hidden states → acceptance collapses at 16K+ ctx (~13-15 t/s). Wrong tool
  for 1K-97K agentic prompts.
- **Embedded MTP head (draft-mtp):** the correct drafter for this arch —
  reads the target's full-context hidden state. 61-70 t/s short, 40-65 t/s
  at 59-97K.
- **n_max 8: rejected** (46.6 t/s vs 66 @ n=3 on this pair — hardware-bound
  kernel shape from the quant author's RTX PRO 4000 does not transfer).
- **--spec-draft-p-min 0.75: rejected** (38.7 t/s vs 61 — the dense MTP
  head's confidence is not a "cheap verify" signal; that advice was for the
  Flash-Next MoE head).
- **ngram + MTP: dead** (v0.4.7 spec dispatch is first-wins, not merge —
  MTP always wins, ngram gets 0 gen drafts).
- **Quant A/B (same flags):** esatapedico native NVFP4 MID-HIGH beat
  cdiamond iMatrix: +8-14% short-context decode, +16% @ 59K (53.7→64-65
  t/s), flatter acceptance decay (pos-3 0.45 vs 0.27 @ 85K), native NVFP4
  (no re-quant round trip) + Q8_0 heads. MID-HIGH won and was the beellama
  primary until this switch.
- `--ctx-checkpoints 4`, `--fit off`, `--split-mode tensor --tensor-split
1,1`, KVarN5/KVarN5 target + KVarN4/KVarN4 draft caches.

## Deployment (what's in the repo)

- `kubernetes/apps/base/ai/llmkube/resources/qwen38-vllm.yaml`
  (enabled; `qwen38-bee-mtp.yaml` commented out — only ONE service may run,
  they share both GPUs)
- `Model qwen38-vllm-nvfp4` →
  `hf://gittensor-model-hub/Qwen3.8-27B-NVFP4-RTX5090@0cc27958cefbbe231782ec8511de8c4eb5233348`
  — **the revision pin is load-bearing for this file**: later commits dropped the MTP
  head (upstream moved to a separate DSpark drafter). No published quality eval for this
  quant; our A/B included the quality probes above (pass).
- Gated candidates in `resources/` (commented out in the kustomization, mutually
  exclusive with the active file — same `qwen38` isvc + 2 GPUs):
  `qwen38-sglang.yaml` (SGLang v0.5.20; first attempt failed boot - 128/256
  tensor mismatch, root cause untraced - and under-provisioned host RAM,
  now corrected to 14Gi. Staged 2026-09-28 as DSpark-NVFP4 draft
  (gittensor 1.41 GB drafter) + fp8 KV, with the flashinfer-prefill /
  trtllm_mha-decode backend split; the NVFP4-KV variant was tried and
  reverted the same day — upstream #36010 makes NVFP4 KV + speculative
  decode dead on v0.5.20, confirmed on 2x 5060 Ti TP2 (our cards); see
  its header VERDICT + the NVFP4-KV watch item below)
  and `qwen38-dspark.yaml` (vLLM 0.30.0 + gittensor DSpark v2 drafter on the
  FINAL headless build: same Model name pinned to main @ `5b7a687f` — 17.92 GB,
  MTP head removed, lm_head NVFP4 — with the 1.41 GB NVFP4 drafter; the MTP
  service keeps the @0cc27958 pin because its spec needs the head).
- `InferenceService qwen38`, runtime `vllm`, `vllm/vllm-openai:v0.30.0`,
  TP2, `maxModelLen 262144` (KV pool 278,927 tokens @ 1.06× — byte-identical
  to the recipe's measurement, good cross-validation), `kvCacheDtype
fp8_e4m3`, prefix caching + chunked prefill, `maxNumBatchedTokens 4096`
  (8192 gains nothing and caps ctx at 200K), `gpuMemoryUtilization 0.95`,
  FLASHINFER attention (TRITON_ATTN measured −33% @32K / −64% @131K — the
  "fused multi-step draft" log line it silences is worth ~0.7%, do NOT
  switch).
- extraArgs: `--speculative-config '{"method":"mtp","num_speculative_tokens":4}'`
  (llmkube's `vllmConfig.speculative` only supports separate-draft-model
  form), `--compilation-config PIECEWISE` (FULL graphs: +2.4% steps/s, no
  tok/s gain, −3.2K pool), `--no-enable-flashinfer-autotune` (OOMs on >0.28.0),
  `--disable_custom_all_reduce` + `NCCL_P2P_DISABLE=1` (GeForce P2P),
  `--mamba-cache-dtype/--mamba-ssm-cache-dtype bfloat16` (+22% KV pool,
  bit-identical), `--load-format ipc_cache`, served-model-name
  `qwen38_27B`, `--reasoning-parser qwen3`, `--tool-call-parser
qwen3_xml`, `--default-chat-template-kwargs '{"preserve_thinking":true}'`.
- **No `--api-key`** — the beellama service was keyless and litellm/karaseek
  send a dummy key; the Service stays ClusterIP + SSO-fronted.
- **Port 8080 + served-model-name `qwen38_27B`** — drop-in for the existing
  clients (`qwen38.ai.svc.cluster.local:8080`, litellm model
  `openai/qwen38_27B`, karaseek `INFERENCE_TEXT_MODEL`).
- **`/dev/shm` 8Gi tmpfs emptyDir (user addition, required):** the
  operator's default shm size breaks vLLM TP2 NCCL IPC — the pod will not
  deploy without the `extraVolumes`/`extraVolumeMounts` block.
- `ks.yaml` health checks: Model `qwen38-vllm-nvfp4` (+ the two old beellama
  Model checks removed; the old Model CRs are now pruned, fallback =
  ~35 GB re-download).
- `--trust-remote-code` deliberately omitted (deprecated; qwen35 arch is
  native). First thing to add if a future image bump fails at model load
  with an arch error.

## Fallback to beellama

1. `resources/kustomization.yaml`: re-enable `qwen38-bee-mtp.yaml`, comment
   out `qwen38-vllm.yaml`
2. `ks.yaml` healthCheckExprs are generic across Model kinds - no swap
3. Re-create the beellama Model CRs (pruned) - models re-download, then
   rolling update swaps the service. ~17 GB per model on the PVC.

## MTP-beellama final test (2026-09-28) - the beellama endgame confirmed

`qwen38-dflash.yaml` renamed to `qwen38-bee-mtp.yaml` (DFlash2 relic Model
CR `qwen38-dflash2-draft` deleted; cdiamond iMatrix target keeps its legacy
Model name `qwen38-dflash-27b` for the PVC cache). Same config as the
68.1 t/s baseline (MID-HIGH NVFP4 + embedded MTP k=3, tensor split).

Warm-state A/B (pod qwen38-55d877785f-bt648; the bench's first short-prose
run is always graph-compile cold and reads ~51 t/s - warm reruns settle at
51.8-56.5):

| Probe                 | MTP-bee (this test)            | vLLM b12x               | DSpark-bee layer |
| --------------------- | ------------------------------ | ----------------------- | ---------------- |
| Short prose           | 51.8-56.5 t/s                  | ~72 t/s                 | 34.1 t/s         |
| Structured JSON x3    | 85.0-85.3 t/s                  | 108.1 t/s (accept 2.64) | 45.0 t/s         |
| Long 64.7K COLD       | 52.6 s (1306 t/s prefill)      | 32.7 s @68.6K           | 82.5 s           |
| Long WARM             | 3.25 s                         | 3.15 s                  | 4.80 s           |
| Draft mean len        | 2.92-2.95 (pos 0.77/0.62/0.52) | 2.64 (MTP k=4)          | 2.44             |
| Quality (math + tool) | PASS                           | PASS                    | PASS             |

Reading: pos-1 acceptance 0.773-0.780 exactly matches the historical 0.78
baseline - config parity confirmed. Structured 85 t/s is the beellama-side
winner (vs DSpark-bee's 45 t/s) and prefill ties the MTP baseline (1306 vs
1339 t/s), so MTP-beellama stays the beellama endgame / fallback. Short
prose ~55 t/s sits ~23% below vLLM b12x (~72), so vLLM stays primary.
One WARN: 'backend offload failed for seq_id=0; using CPU sampler' -
same condition as the 68.1-era baseline (not a regression).

## b12x NVFP4 GEMM A/B (2026-09-28) - final: b12x wins on structured

vLLM 0.30.0 ships an SM120-specific NVFP4 GEMM
(`FlashInferB12xNvFp4LinearKernel`, FlashInfer 0.6.18 CuTe-DSL
`Sm120BlockScaledDenseGemmKernel`). Auto-selection ranks CUTLASS above it
(`_POSSIBLE_NVFP4_KERNELS` order), so the service ran on
`FlashInferCutlassNvFp4LinearKernel` until opted in via
`--kernel-config '{"linear_backend": "flashinfer_b12x"}'`.

Paired A/B: same day, same node, zero concurrency in either window
(`Running: 2` never appeared in the pod stats), same script
(`scripts/llm_bench.py`), identical prompts (the ~65-69K filler is
salted per run so each "cold" is genuinely cold; JSON/prose/math/tool
prompts are content-fixed, so both kernels ran on the SAME content):

| Probe (identical content)         | b12x                       | cutlass (auto)        | delta                  |
| --------------------------------- | -------------------------- | --------------------- | ---------------------- |
| KV pool                           | 279,726 tok                | 278,927 tok           | invariant (+0.3%)      |
| Short prose, 512 tok @ temp 1.0   | 7.73 s (66.3 t/s)          | 7.90 s (64.8 t/s)     | ~tie                   |
| Structured JSON, 3000 tok cap x3  | **108.1 t/s, accept 2.64** | 94.0 t/s, accept 2.32 | **+15%, +0.32 accept** |
| Long COLD ~65.7K / ~68.6K prefill | 31.66 s (2,075 t/s)        | 32.65 s (2,101 t/s)   | tie                    |
| Long WARM wall (prefix cache)     | 3.16 s                     | 3.15 s                | tie                    |
| Math probe (70336)                | PASS                       | PASS                  | quality preserved      |
| Tool call (get_weather)           | PASS                       | PASS                  | quality preserved      |

Findings:

- The b12x win is an ACCEPTANCE story: on identical content, the b12x
  GEMM numerics preserve MTP draft->target agreement better
  (2.64 vs 2.32 accepted tokens/step), and structured output (where
  acceptance drives t/s most) picks that up directly.
- The intermediate "wash-to-negative" read (108 vs the recorded 123 t/s)
  was a prompt-content confound: 123 t/s was a DIFFERENT JSON prompt
  (accept ~4.2-4.6). On this prompt cutlass only reaches 94 t/s. For
  structured output, prompt content dominates t/s far more than the
  kernel - future structured comparisons must pin the prompt (the bench
  script now does).
- Cold prefill: b12x is NOT slower (tie at normalized t/s); the earlier
  "prefill loss" read was a token-count + week-old-baseline artifact.
- Native `B12xNvFp4LinearKernel` (the `vllm[b12x]` extra, not in the
  stock image) stays parked as the zot-custom-image escalation path.

Verdict: **re-enable b12x** - the agentic profile (structured output +
warm long context) is exactly where it wins. Two-line uncomment in
`qwen38-vllm.yaml` (candidate block carries the full history).

## MTP deep-k A/B: k=6 vs k=4 (2026-09-28) - k=4 stays

Hypothesis: b12x improved deep-position acceptance (2.32 -> 2.64), so a
deeper draft (k=6) might now pay off. Pod qwen38-74685b859-2vgjk, b12x
active, paired `scripts/llm_bench.py --port-forward`, zero concurrency:

| Probe                 | k=4 (recorded)          | k=6 (this test)                      |
| --------------------- | ----------------------- | ------------------------------------ |
| Short prose (512 tok) | 7.73 s (66.3 t/s)       | 8.68 s (59.0 t/s, -11%)              |
| Structured JSON x3    | 108.1 t/s (accept 2.64) | 84.4-85.4 t/s (accept 2.36, -22%)    |
| Pool                  | 279,726                 | 273,333 (1.04x of 262K - still fits) |
| Long prefill          | 2076 t/s (65.7K 31.7 s) | 2000 t/s (74.4K 37.2 s - wash)       |
| Long warm             | 3.16 s (68.6K)          | 3.62 s (74.4K)                       |
| Quality               | PASS                    | PASS                                 |

k=6 per-pos acceptance (mixed traffic): 0.76/0.54/0.40/0.29/0.23/0.18 -
the acceptance curve is healthy; what kills deep k is the PER-STEP COST:
vLLM runs the MTP layer forward multiple times for k>1 (vLLM warning)
and FLASHINFER rebuilds attention metadata between draft steps (fused
multi-step draft not supported by the backend), both scaling with k.
The recipe's "structured still rising at k=7 (138 t/s)" was cutlass on
their hardware and did not transfer - same class as the beellama
nDraftMax 8 non-transfer (hardware-bound kernel shape).

Verdict: **k=4 stays** (revert committed after this test). RETRY trigger:
FLASHINFER fused multi-step draft decode (vLLM #55292/#57443) lands - it
removes the per-draft-step overhead that makes deep k unprofitable; re-A/B
k=6/8 on that image bump. Full A/B table lives in qwen38-vllm.yaml.

## FULL_AND_PIECEWISE re-test (2026-09-28) - PIECEWISE stays

Pre-b12x measurement said FULL_AND_PIECEWISE was neutral-to-loss
(+2.4% steps/s, no tok/s gain, -3.2K pool). b12x changed the GEMM speed
balance, so re-measured (pod qwen38-7c5c564449-xn7kf, b12x + k=4):

| Probe           | PIECEWISE (recorded)     | FULL_AND_PIECEWISE            |
| --------------- | ------------------------ | ----------------------------- |
| Pool            | 279,726                  | 276,529 (-3.2K)               |
| Short prose     | 7.73 s (66.3 t/s)        | 7.81 s (65.6 t/s)             |
| Structured x3   | 108.1 t/s (accept 2.64)  | 105.1-106.7 t/s (accept 2.51) |
| Long COLD 64.7K | 31.7 s @65.7K (2075 t/s) | 30.23 s (2141 t/s, +3.2%)     |
| Warm            | 3.16 s @68.6K            | 2.97 s @64.7K                 |
| Quality         | PASS                     | PASS                          |

Decode is a tie-to-slightly-soft (within the day-to-day/GPU-clock
confound), prefill is +3%, pool -3.2K. The +2.4% steps/s still did not
convert to tok/s - same verdict as pre-b12x. **PIECEWISE stays**: a 3%
cold-prefill gain is not worth the pool cost + softer decode.

## Async scheduling: already ON by default (verified in-pod, v0.30.0)

`SchedulerConfig.async_scheduling` defaults to `None` = auto, and the auto
path ENABLES it unless a disabling condition applies. MTP is in the
allowlist (`EagleModelTypes` includes `MTPModelTypes`), the multiproc
executor supports it, and no disable warnings appear in the pod logs.
This build exposes NO CLI flag (`--async-scheduling` absent from
entrypoints) - it is purely auto-resolved. Nothing to tune: the
scheduler-execution overlap is already inside all recorded numbers.
Verified 2026-09-28 against the installed v0.30.0 source in
qwen38-7c5c564449-xn7kf.

## NVFP4-KV A/B (2026-10-19) - pool +75% at -19%/-30% t/s; KEPT, isolation pending

The upstream trigger fired: SM120 NVFP4 KV cache shipped in v0.32.0
(#46963 paged slot-mapping writer + FA2 prefill; #60452 XQA decode +
MTP UNIFORM_BATCH cudagraphs - the pre-#60452 "MTP collapses to ~15
tok/s" trap is NOT present in this image: spec-decode counters were
healthy from the first request). Flipped via `kvCacheCustomDtype:
nvfp4` (the standard `kvCacheDtype` CRD enum stops at fp8_e4m3 and
rejects nvfp4 at apply time; the custom field is unvalidated and maps
to --kv-cache-dtype). No `VLLM_KV_CACHE_LAYOUT=HND` env needed - the
merged line validates on the default NHD layout; HND was a requirement
of jethac's UNMERGED #46329 line. Zero-concurrency `scripts/llm_bench.py`,
pod qwen38-7ccfb97d, vs the recorded 0.30.0 fp8 b12x baseline (09-28):

| Probe (pinned content)         | 0.30.0 fp8 (recorded)      | 0.32.0 NVFP4 (this run)   | delta               |
| ------------------------------ | -------------------------- | ------------------------- | ------------------- |
| KV pool                        | 279,726 tok (1.06x of 262K)| **488,973 tok (1.87x)**   | **+75% pool**       |
| Short prose, 512 tok @ temp 1  | 7.73 s (66.3 t/s)          | 9.53 s (53.7 t/s)         | -19%                |
| Structured JSON x3             | 108.1 t/s, acc 2.64        | 75.1-77.9 t/s, acc 2.08   | -28 to -30%         |
| Long COLD prefill              | 31.66 s @65.7K (2,075 t/s) | 31.58 s @68.6K (2,171)    | prefill +4.6% t/s   |
| Long WARM wall                 | 3.16 s @68.6K              | 3.34 s @68.6K             | +0.18 s (wash)      |
| Quality (math + tool)          | PASS                       | PASS                      | preserved           |

Reads:

- The POOL is the win: 1.87x of the 262,144 requirement (was 1.06x) -
  two concurrent ~244K agentic sessions now fit, which is exactly the
  `parallelSlots: 2` intent.
- The acceptance drop (2.64 -> 2.08 accepted/step on the pinned JSON
  prompt) is the NVFP4-precision tax on draft->target agreement - the
  b12x A/B established that acceptance drives structured t/s, and the
  4-bit KV readout degrades it. Prose -19% matches the dual-5060Ti
  datapoint ("max tg 82 (fp8) -> 65 (nvfp4)") almost exactly.
- Prefill is unchanged (FA2 NVFP4 prefill path), warm wall is a wash.
- CONFOUND: the 0.30.0 -> 0.32.0 engine bump (XQA decode is new in
  0.32 even for fp8) is NOT isolated - no fp8@0.32 paired baseline
  (skipped, user call), so the t/s deltas are an upper bound on the
  NVFP4 cost, not its exact size. Also cross-week (clock drift).

VERDICT: KEPT. The trigger was the pool (262K was the binding
constraint), and it delivered 1.87x at the predicted decode tax with
quality probes PASS. FOLLOW-UP: flip to `kvCacheDtype: fp8_e4m3` on
0.32.0 and re-run the same bench to isolate the pure NVFP4 delta
(one-line revert + ~10 min); if the user prioritizes t/s over pool,
that number decides the revert.

## Watch list

- **DSpark drafter** (upstream Qwen moved the MTP head to a separate 1.4 GB
  NVFP4 drafter with parallel block drafting — no per-position cost): CORRECTED
  2026-09-27 — vLLM 0.30.0 DOES ship native dspark support (verified in-pod:
  `config/speculative.py` auto-detects `method=dspark`, rewrites
  `DSparkDraftModel` → built-in `Qwen3DSparkModel` runner, `qwen3_dspark.py`
  with Markov + confidence heads; `enable_adaptive_verification` is
  dspark-only). The open risk is the documented 128-vs-256 NVFP4 lm_head
  packing mismatch when loading the NVFP4 draft — so `qwen38-dspark.yaml`
  stages the card's recommended pairing (gittensor final headless target +
  `Qwen3.8-27B-DSpark-NVFP4` @ `eba1ac5a`, 1.41 GB) with the BF16 RadixArk
  stock drafter and MTP k=4 as commented fallbacks. BOOT TESTED
  2026-09-27: the draft failed to load and the drafter footprint squeezed
  the pool too hard — reverted to MTP k=4 (`qwen38-vllm.yaml` active
  again). The pairing stays the candidate; re-test each vLLM bump.
- **FlashInfer fused multi-step draft decode** (vLLM #55292/#57443, issue
  #54369 "rebuild fallback caps useful MTP depth at k=4"): when it lands
  for FlashInfer, the k=0..7 sweep is worth re-running — k=5-7 could start
  paying for prose too, and the 2.37 ms/position floor moves. Baseline
  for the re-sweep: k=6 tested 2026-09-28 and LOSEd (structured 85 vs 108
  t/s at k=4; see the MTP deep-k section) - deep k is currently capped by
  the per-draft-step cost this PR would remove.
- **NVFP4 KV cache for GDN models**: would halve the ~18.4 KiB/token
  attention KV (GDN state unchanged) → ~500K-token pool, and shrink the
  at-depth step-rate decay (−18% steps/s at 131K). DECISION 2026-09-27
  (REVISED): the vLLM side still WAITS FOR UPSTREAM — SM120 support
  exists only in open vLLM PRs (#46329 jethac foundation: FA2 paged
  NVFP4 reader + linear V-scale writer + HND layout; #56550/#56552, the
  split of closed #50288), so even nightly lacks it and NO off-the-shelf
  image exists (checked 2026-09-27: co-l's gist builds the image locally,
  jethac publishes wheels not containers, Docker Hub "nvfp4" images are
  model-bundled or pre-feature). SGLang v0.5.20 DOES ship an NVFP4 KV
  recipe for SM120 (`--kv-cache-dtype nvfp4` -> flashinfer dequant-
  workspace prefill + trtllm_mha native-FP4 XQA decode), BUT **with
  speculative decoding it is broken**: upstream #36010 (open, no fix in
  0.5.20) - spec verify batches are gpu-only so the FlashInfer dequant
  path sees `extend_prefix_lens_cpu = None` and the scheduler dies; a
  second confirmation ran on 2x 5060 Ti TP2 (our exact cards) on the
  official 0.5.20 wheel. External drafts (DSpark) are doubly dead:
  `--speculative-draft-attention-backend` takes one value for both draft
  phases, but the NVFP4 pool needs flashinfer (extend) + trtllm_mha
  (decode). DECISION 2026-09-28 (boot-tested, user): reverted the SGLang
  staging to `kvCacheDtype: fp8_e4m3` + DSpark NVFP4 draft (the KV pool
  itself allocates fine on 16GB pairs - ~200K tokens on the #36010
  repro box - so the no-spec NVFP4-KV experiment stays parked, needing
  the #36010 16GB trap handled too: pin `--max-total-tokens` or the
  prefill graph-capture ladder OOMs at ~0 GB headroom). Evidence on our
  exact cards (dual 5060 Ti, #50288 thread): "nvfp4 working perfectly,
  no hallucinations; max tg 82 (fp8) → 65 (nvfp4) with MTP" — ~1.6×
  pool (scale groups cost bytes) at a decode-speed cost. TRIGGER FIRED
2026-10-19: the vLLM PRs shipped in v0.32.0 (#46963/#60452); A/B'd on
this box and KEPT - see the NVFP4-KV A/B section above (pool +75% at
-19%/-30% t/s, quality PASS, no HND env needed, llmkube custom-field
escape hatch). Residual watch: #36010 (fix candidates in-thread:
CPU-mirror population - graphs-off only; #36045 graph-safe workspace
prep; #23354 fused NVFP4 extend kernel) -> SGLang NVFP4-KV + DSpark
re-test when it lands in a release; fp8@0.32.0 isolation bench
(pending) to pin the pure NVFP4 t/s delta.
- **SGLang + DSpark on 2×16GB: SHELVED 2026-09-28 (user decision,**
  **agreed)**. Three boot attempts: (1) f=0.90 → OOM at the prefill
  capture ladder; (2) f=0.98 → worse (memFractionStatic is the
  CEILING, the pool fills it; 20 MiB allocation died with 8 MiB free);
  (3) f=0.88 + `--max-total-tokens 98304` + chunked 1024 → engine
  STARTS (`max_total_num_tokens` clamps to 90304, `available_gpu_mem`
  0.65 GB, prefill + DSpark draft graphs auto-disabled) but every
  lazily-compiled Triton kernel then device-loads into the remaining
  0.46-0.50 GB ("Pre-load it during engine init to avoid CUDA OOM") —
  the #36010 16GB-card trap: boots at ~0 GB headroom, first request
  OOMs. Decisive numbers: SGLang+DSpark pool ≈ 90K vs vLLM's 278,927
  measured (DSpark's separate draft runner + draft KV pool + verify
  graphs cost 2-4 GB/rank that the in-checkpoint MTP head doesn't);
  90K < the 59K×2 agentic session; all three graph features off to
  boot at all; DSpark's acceptance was never measured on this box
  (3.16× is H200 cookbook data). The ladder (mamba ratio 8, mrr 1,
  chunked 512) reclaims ~10-20K tokens max — the pool ceiling is
  structural. Revisit only when: #36010 fix lands in an SGLang
  release (NVFP4 KV → 2× pool unblocks spec decode on our cards),
  DSpark's draft footprint shrinks upstream (~150K+ pool at f=0.88),
  or bigger GPUs arrive. Full saga in `qwen38-sglang.yaml` header.
- **`b12x` SM120 NVFP4 GEMM - A/B COMPLETE 2026-09-28, b12x wins on
  structured** (full table: "b12x NVFP4 GEMM A/B" section above): it
  ships in vLLM 0.30.0 (pod-verified `is_supported()` True on our
  cards); auto ranks CUTLASS first, so it is opt-in via
  `--kernel-config '{"linear_backend": "flashinfer_b12x"}'`. Paired,
  same-content result: structured +15% (accept 2.64 vs 2.32), ties
  elsewhere, quality probes pass, pool invariant. Native `vllm[b12x]`
  extra (non-FlashInfer kernel) remains the escalation via a
  zot-hosted custom image.
- **DSpark on beellama - TESTED 2026-09-28: tensor split CRASH, layer
  split LOSE; kept as the tensor-split retry template
  (`qwen38-dspark-bee.yaml`, gated).** beellama v0.4.7 implements the
  DFlash/DSpark draft family
  itself (initially misread as engine-native to SGLang/vLLM only): the
  fork's args doc says KVarN is "runtime-qualified on CUDA for
  ... non-MLA DSpark contexts" and the draft ubatch grows to
  `max(128, parallel*(n_max+1))` "for parallel DFlash/DSpark" (merged
  noise blocks = block-diffusion drafting); the operator CRD has typed
  `speculativeDecoding.type: draft-dspark` + `draftModelRef` (the draft
  Model CR is downloaded and cached like the target - no HF
  re-download on every pod restart, the vLLM-DSpark pain point). The
  drafter GGUF exists: `Anbeeld/Qwen3.8-27B-DSpark-GGUF` (the beellama
  author's own build of RadixArk's 1.86B drafter; ladder Q2_K..Q8_0,
  flat sizes ~1.0-1.1 GB, Q4_K_M picked). The drafter was co-trained
  and acceptance-evaluated against NVFP4 targets (RadixArk
  Qwen3.8-27B-NVFP4), so the pairing is the tuned one. Staged
  candidate: MID-HIGH NVFP4 target (qwen38-bee-mtp.yaml fork, everything
  identical except the spec mechanism), draft-dspark typed block with
  n-max omitted (clamps to the drafter's trained block-7 limit),
  kvarn4 draft cache. Published acceptance (SGLang GB300/H200, v2):
  aggregate 3.43/step (math 4.2-4.5, RULER-8K 6.3, LongBench-v2 3.9)
  vs MTP k=3 ~2.5 - the DFlash2 2048-token SWA-window long-context
  collapse is exactly what the full-attention DSpark fixes. Numbers to
  beat: beellama MTP k=3 68.1 t/s short / 53.7 t/s @59K / prefill
  1339 t/s; vLLM primary 72 t/s / 59K 21s cold 4.1s warm / structured
  108 t/s. OUTCOME: **attempt 1 (tensor split) = crash** on the first spec
  step - `ggml-backend-meta.cpp:621 SPLIT_AXIS_UNKNOWN`, a known upstream
  bug class (llama.cpp #27819 DFlash2 reproduced on exactly 2x5060Ti,
  #27964 open, #26339 not_planned; community fix PR #27858 open/unmerged,
  v0.4.7 newest stable; draft-KV cache type irrelevant - f16/q8_0/q4_0/
  kvarn4/kvarn5 all crash identically). **Attempt 2 (layer split = the
  documented #27819 workaround) = boots, serves, quality PASS, but LOSE
  across the board** (scripts/llm_bench.py --port-forward, pod
  qwen38-596f5b69c8-6x5w6): short 34.1 t/s (MTP-bee 68.1, vLLM 72),
  structured 45.0 t/s x3 (vLLM b12x 108), long COLD 68.5K 82.5s (MTP-bee
  21s - layer prefill = per-layer allreduce over PCIe, ~831 t/s vs the
  ~2.8K t/s class of tensor-mode), warm 4.80s (tie vs 4.1), draft mean len
  2.44 (pos 0.63/0.46/0.35 - below MTP-vLLM 2.64 and the published H200
  3.43; one prefix-warm task hit 0.89-0.93), WARN "target output split
  across devices; using CPU draft sampler". VERDICT: shelve layer mode
  (the 2x decode + ~4x prefill penalty eats the acceptance gain); vLLM b12x
  stays primary, MTP-beellama stays the beellama endgame. RETRY trigger:
  #27858 merges and a beellama release ships it -> flip the candidate to
  --split-mode tensor + --tensor-split 1,1 (the file is the ready
  template) and re-test: tensor decode is ~2x faster and would make the
  structured acceptance the deciding factor.
- **Qwen3.8-Flash-Next** (125B/6B-active MoE, QSA, n-gram tables): not
  viable on 2×16GB (119 GiB NVFP4 + 28.8 GB n-gram table mandatory in
  host RAM; 64 GB node can't host the offload). Next-GPU-generation model.
