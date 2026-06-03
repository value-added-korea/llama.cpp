#!/usr/bin/env bash
# serve-qwen3-5-27b-mtp-vulkan.sh
#
# Serves Qwen3.5-27B-Q4_K_M with MTP (Multi-Token Prediction) speculative
# decoding via the Vulkan / AMD 780M iGPU build.
#
# References:
#   https://github.com/ggml-org/llama.cpp/pull/22673
#   https://huggingface.co/bartowski/Qwen_Qwen3.5-27B-GGUF
#
# ── What MTP does ─────────────────────────────────────────────────────────
#  The Qwen3.5 GGUF from bartowski has MTP draft heads baked in.  On each
#  forward pass, the model speculatively predicts 2 additional tokens beyond
#  the current one (draft-n-max 2).  If accepted (70-82% rate), output grows
#  by multiple tokens per pass, boosting TG throughput ~1.2x on APU hardware.
#
#  Tradeoff: prompt processing (PP) slows by ~0.5x due to device-to-host
#  embedding transfers required by the draft heads.
#
# ── Memory budget (22 GB free RAM at idle, UMA) ──────────────────────────
#  Model weights   : ~17.98 GB
#  MTP head cache  : ~2.0–2.5 GB  (< 10 % of model per PR author)
#  KV cache @4096  : ~0.3 GB      (q8_0, 4096 tokens, 64 layers, 4 KV heads)
#  OS headroom     : ~1.5 GB
#  ─────────────────────────────────────────────────────────────────────────
#  Total           : ~22 GB  →  NGL=45 keeps working set within budget
#
#  Increase N_CTX or N_GPU_LAYERS only if free RAM is well above 22 GB.
#
# ── Known Vulkan / MTP caveats ────────────────────────────────────────────
#  • --parallel MUST stay at 1.  MTP hard-errors on n_parallel > 1.
#  • flash-attn is disabled: Vulkan build reports flash_attn=-1 (unsupported).
#  • One user reported low MTP acceptance (~1%) on RDNA4 Vulkan; if you see
#    garbled output or acceptance_rate < 0.05 in the log, disable MTP by
#    removing --spec-type draft-mtp and run without speculative decoding.
#
# ── Thinking mode ─────────────────────────────────────────────────────────
#  ON  by default  →  model emits <think>…</think> reasoning blocks.
#  Disable per-request via API:
#    {"chat_template_kwargs": {"enable_thinking": false}}
#
# ── Download ──────────────────────────────────────────────────────────────
#  huggingface-cli download bartowski/Qwen_Qwen3.5-27B-GGUF \
#    --include "Qwen_Qwen3.5-27B-Q4_K_M.gguf" \
#    --local-dir /mnt/512_ssd_internal/vai-llm-tei/llm-models/
#
# ── Sampling presets (Qwen3 official, ref: unsloth model card) ────────────
#  Thinking / general : temp=1.0  top_k=20  top_p=0.95  (default here)
#  Coding / precise   : TEMP=0.6  bash serve-qwen3-5-27b-mtp-vulkan.sh
#  Instruct (no CoT)  : TEMP=0.7  TOP_P=0.80  bash serve-qwen3-5-27b-mtp-vulkan.sh
#
# ── Overridable env vars ──────────────────────────────────────────────────
#  N_GPU_LAYERS=50  N_CTX=8192  PORT=8082  TEMP=0.6  bash <script>

set -euo pipefail

# ── AMD 780M isolation ────────────────────────────────────────────────────
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json
export CUDA_VISIBLE_DEVICES=""
unset  CUDA_DEVICE_ORDER 2>/dev/null || true

# ── Paths ─────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$REPO_ROOT/build-vulkan-aocc"
BINARY="$BUILD_DIR/bin/llama-server"
MODEL="/mnt/512_ssd_internal/vai-llm-tei/llm-models/Qwen_Qwen3.5-27B-Q4_K_M.gguf"

# ── Parameters ────────────────────────────────────────────────────────────
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8082}"

# 4096 is the safe default given 22 GB free RAM + MTP overhead.
# Raise to 8192 only when free RAM is confirmed > 24 GB before launch.
N_CTX="${N_CTX:-4096}"

# 45/64 layers on GPU = ~12.6 GB.  Leaves ~7 GB for MTP heads + KV + OS.
# Max theoretical with current RAM: ~48 layers.
N_GPU_LAYERS="${N_GPU_LAYERS:-45}"

# Physical cores only — hyperthreading hurts token-gen throughput.
N_THREADS="${N_THREADS:-8}"

# MTP hard-requires parallel=1.  Do not change this.
N_PARALLEL=1

# Batch sizes — matched to bench config for consistency.
N_BATCH="${N_BATCH:-2048}"
N_UBATCH="${N_UBATCH:-512}"

# MTP draft tokens per step.  APU sweet spot is 2 (memory-bandwidth limited).
# Increasing to 3 rarely helps on iGPU and increases rejection-path overhead.
MTP_DRAFT_N="${MTP_DRAFT_N:-2}"

# KV cache quantisation — q8_0/q8_0 is the PR-recommended pairing for MTP.
# q4_0 for type_v causes measurable throughput loss and is not recommended.
KV_TYPE_K="${KV_TYPE_K:-q8_0}"
KV_TYPE_V="${KV_TYPE_V:-q8_0}"

# Sampling — Qwen3 thinking-mode recommended defaults.
TEMP="${TEMP:-1.0}"
TOP_K="${TOP_K:-20}"
TOP_P="${TOP_P:-0.95}"
MIN_P="${MIN_P:-0.0}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.0}"

# ── Pre-flight: Vulkan device isolation ───────────────────────────────────
echo "[preflight] Checking Vulkan device isolation..."
if command -v vulkaninfo &>/dev/null; then
    VK_DEVICES=$(VK_ICD_FILENAMES="$VK_ICD_FILENAMES" \
        vulkaninfo --summary 2>/dev/null | grep -i "deviceName" || true)
    if echo "$VK_DEVICES" | grep -qi "nvidia\|rtx\|geforce"; then
        echo "[ABORT] NVIDIA device visible — check VK_ICD_FILENAMES"
        exit 1
    fi
    echo "[OK] Vulkan:$(echo "$VK_DEVICES" | sed 's/.*deviceName\s*=\s*/  /')"
else
    echo "[WARN] vulkaninfo not found — skipping Vulkan check"
fi

# ── Pre-flight: sanity checks ─────────────────────────────────────────────
if [[ ! -f "$BINARY" ]]; then
    echo "[ABORT] Binary not found: $BINARY"
    echo "        Build with: cmake --preset vulkan-aocc && cmake --build build-vulkan-aocc -j\$(nproc)"
    exit 1
fi

if [[ ! -f "$MODEL" ]]; then
    echo "[ABORT] Model not found: $MODEL"
    echo ""
    echo "  Download with:"
    echo "    huggingface-cli download bartowski/Qwen_Qwen3.5-27B-GGUF \\"
    echo "      --include 'Qwen_Qwen3.5-27B-Q4_K_M.gguf' \\"
    echo "      --local-dir /mnt/512_ssd_internal/vai-llm-tei/llm-models/"
    exit 1
fi

# ── Pre-flight: RAM check ─────────────────────────────────────────────────
AVAIL_MIB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
# Minimum to load safely: model (18432) + MTP (2048) + KV + OS = ~21500 MiB
MIN_MIB=21500
if (( AVAIL_MIB < MIN_MIB )); then
    echo "[WARN] Only ${AVAIL_MIB} MiB free; recommend >= ${MIN_MIB} MiB for safe MTP operation"
    echo "       Reduce N_CTX or close other applications if you see OOM errors"
else
    echo "[OK] Available RAM: ${AVAIL_MIB} MiB (>= ${MIN_MIB} MiB required)"
fi

# ── Launch ────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Qwen3.5-27B-Q4_K_M — Vulkan (AMD 780M) + MTP"
echo "  NGL=$N_GPU_LAYERS/64  CTX=$N_CTX  draft-n-max=$MTP_DRAFT_N"
echo "  KV: k=$KV_TYPE_K  v=$KV_TYPE_V"
echo "  temp=$TEMP  top_k=$TOP_K  top_p=$TOP_P"
echo "  Listening: http://$HOST:$PORT"
echo "========================================================"
echo ""

exec "$BINARY" \
    --model          "$MODEL" \
    --host           "$HOST" \
    --port           "$PORT" \
    --ctx-size       "$N_CTX" \
    --n-gpu-layers   "$N_GPU_LAYERS" \
    --threads        "$N_THREADS" \
    --parallel       "$N_PARALLEL" \
    --batch-size     "$N_BATCH" \
    --ubatch-size    "$N_UBATCH" \
    --cache-type-k   "$KV_TYPE_K" \
    --cache-type-v   "$KV_TYPE_V" \
    --spec-type      draft-mtp \
    --spec-draft-n-max "$MTP_DRAFT_N" \
    --temp           "$TEMP" \
    --top-k          "$TOP_K" \
    --top-p          "$TOP_P" \
    --min-p          "$MIN_P" \
    --repeat-penalty "$REPEAT_PENALTY" \
    --jinja \
    --log-prefix \
    "$@"
