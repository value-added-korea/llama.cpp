#!/usr/bin/env bash
# serve-qwen3-27b-vulkan.sh
# Serves Qwen3.6-27B-Q4_K_M via llama-server using the Vulkan (AMD 780M iGPU) build.
#
# Model:   Qwen3.6-27B-Q4_K_M (~16 GB, 64 layers, 262K native context)
# Backend: Vulkan — AMD Radeon 780M (RADV PHOENIX, UMA, gfx1103)
# NGL:     50/64 layers (~12.5 GB on GPU, ~3.5 GB on CPU)
#
# Thinking mode is ON by default (model emits <think>...</think> blocks).
# To disable per-request, pass:  {"chat_template_kwargs": {"enable_thinking": false}}
#
# Overridable via environment:
#   N_GPU_LAYERS=64  N_CTX=16384  PORT=8080  bash serve-qwen3-27b-vulkan.sh
#
# Sampling presets (Qwen3 official recommendations):
#   Thinking/general:  temp=1.0  top_k=20  top_p=0.95  (default here)
#   Coding/precise:    temp=0.6  top_k=20  top_p=0.95
#   Instruct mode:     temp=0.7  top_k=20  top_p=0.80  presence_penalty=1.5
# Set TEMP, TOP_K, TOP_P env vars to override.

set -euo pipefail

# ── AMD 780M isolation ──────────────────────────────────────────────────────
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json
export CUDA_VISIBLE_DEVICES=""
unset  CUDA_DEVICE_ORDER 2>/dev/null || true

# ── Paths ───────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$REPO_ROOT/build-vulkan-aocc"
BINARY="$BUILD_DIR/bin/llama-server"
MODEL="/mnt/512_ssd_internal/vai-llm-tei/llm-models/Qwen3.6-27B-Q4_K_M.gguf"

# ── Parameters (all overridable via env) ────────────────────────────────────
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"

# Context: 8192 is practical for 780M; increase if you have spare RAM.
# At f16 KV, each 1K context costs ~0.5 GB KV cache for this model.
N_CTX="${N_CTX:-8192}"

# 50/64 layers on GPU: ~12.5 GB. Increase toward 64 if RAM allows.
# Decrease if you see out-of-memory errors at load time.
N_GPU_LAYERS="${N_GPU_LAYERS:-50}"

# Physical CPU cores — handles the 14 non-offloaded layers + host ops
N_THREADS="${N_THREADS:-8}"

# Number of concurrent inference slots (each costs ~N_CTX * KV_size RAM)
N_PARALLEL="${N_PARALLEL:-1}"

# Batch/micro-batch sizes (matched to bench config)
N_BATCH="${N_BATCH:-2048}"
N_UBATCH="${N_UBATCH:-512}"

# Sampling defaults — Qwen3 "thinking" mode recommended values
TEMP="${TEMP:-1.0}"
TOP_K="${TOP_K:-20}"
TOP_P="${TOP_P:-0.95}"
MIN_P="${MIN_P:-0.0}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.0}"

# ── Pre-flight: confirm AMD 780M is the only Vulkan device ─────────────────
echo "[preflight] Checking Vulkan device isolation..."
if ! command -v vulkaninfo &>/dev/null; then
    echo "[WARN] vulkaninfo not found — skipping Vulkan check"
else
    VK_DEVICES=$(VK_ICD_FILENAMES="$VK_ICD_FILENAMES" vulkaninfo --summary 2>/dev/null \
        | grep -i "deviceName" || true)
    if echo "$VK_DEVICES" | grep -qi "nvidia\|rtx\|geforce"; then
        echo "[ABORT] NVIDIA device visible in Vulkan enumeration — check VK_ICD_FILENAMES"
        echo "        VK_ICD_FILENAMES=$VK_ICD_FILENAMES"
        exit 1
    fi
    echo "[OK] Vulkan devices:"
    echo "$VK_DEVICES" | sed 's/^/       /'
fi

# ── Sanity checks ───────────────────────────────────────────────────────────
if [[ ! -f "$BINARY" ]]; then
    echo "[ABORT] Binary not found: $BINARY"
    echo "        Build with: cmake --preset vulkan-aocc && cmake --build build-vulkan-aocc -j\$(nproc)"
    exit 1
fi
if [[ ! -f "$MODEL" ]]; then
    echo "[ABORT] Model not found: $MODEL"
    exit 1
fi

# ── Launch ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Qwen3.6-27B-Q4_K_M — Vulkan (AMD 780M iGPU)"
echo "  NGL=$N_GPU_LAYERS/64  CTX=$N_CTX  Parallel=$N_PARALLEL"
echo "  temp=$TEMP  top_k=$TOP_K  top_p=$TOP_P"
echo "  Listening: http://$HOST:$PORT"
echo "========================================================"
echo ""

exec "$BINARY" \
    --model         "$MODEL" \
    --host          "$HOST" \
    --port          "$PORT" \
    --ctx-size      "$N_CTX" \
    --n-gpu-layers  "$N_GPU_LAYERS" \
    --threads       "$N_THREADS" \
    --parallel      "$N_PARALLEL" \
    --batch-size    "$N_BATCH" \
    --ubatch-size   "$N_UBATCH" \
    --temp          "$TEMP" \
    --top-k         "$TOP_K" \
    --top-p         "$TOP_P" \
    --min-p         "$MIN_P" \
    --repeat-penalty "$REPEAT_PENALTY" \
    --jinja \
    --log-prefix \
    "$@"
