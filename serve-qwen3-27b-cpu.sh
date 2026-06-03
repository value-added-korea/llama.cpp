#!/usr/bin/env bash
# serve-qwen3-27b-cpu.sh
# Serves Qwen3.6-27B-Q4_K_M via llama-server using the CPU-only (AOCC) build.
#
# Model:   Qwen3.6-27B-Q4_K_M (~16 GB, 64 layers, 262K native context)
# Backend: CPU — AMD Ryzen 7 8845HS (Zen 4, 8C/16T), AOCC-compiled
# NGL:     0 (no GPU offload)
#
# Model is mmap'd from SSD — does not require 16 GB RAM upfront.
# Full inference RAM cost: ~16 GB weights + KV cache (~0.5 GB per 1K ctx).
#
# Thinking mode is ON by default (model emits <think>...</think> blocks).
# To disable per-request, pass:  {"chat_template_kwargs": {"enable_thinking": false}}
#
# Overridable via environment:
#   N_THREADS=16  N_CTX=4096  PORT=8081  bash serve-qwen3-27b-cpu.sh
#
# Sampling presets (Qwen3 official recommendations):
#   Thinking/general:  temp=1.0  top_k=20  top_p=0.95  (default here)
#   Coding/precise:    temp=0.6  top_k=20  top_p=0.95
#   Instruct mode:     temp=0.7  top_k=20  top_p=0.80  presence_penalty=1.5

set -euo pipefail

# ── Suppress GPU paths ──────────────────────────────────────────────────────
export CUDA_VISIBLE_DEVICES=""
unset  CUDA_DEVICE_ORDER 2>/dev/null || true

# ── Paths ───────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$REPO_ROOT/build-cpu-aocc"
BINARY="$BUILD_DIR/bin/llama-server"
MODEL="/mnt/512_ssd_internal/vai-llm-tei/llm-models/Qwen3.6-27B-Q4_K_M.gguf"

# ── Parameters (all overridable via env) ────────────────────────────────────
HOST="${HOST:-127.0.0.1}"

# Use a different port than the Vulkan server so both can run simultaneously
PORT="${PORT:-8081}"

# CPU is the bottleneck for KV cache bandwidth — keep context modest.
# Each 1K context costs ~0.5 GB RAM for this model at f16 KV.
N_CTX="${N_CTX:-4096}"

# Use physical cores only — hyperthreading hurts llama.cpp token gen throughput.
# 8845HS has 8 physical cores.
N_THREADS="${N_THREADS:-8}"

# One slot is enough for CPU — parallel slots multiply RAM and hurt throughput.
N_PARALLEL="${N_PARALLEL:-1}"

# Smaller ubatch improves first-token latency on CPU
N_BATCH="${N_BATCH:-512}"
N_UBATCH="${N_UBATCH:-512}"

# Sampling defaults — Qwen3 "thinking" mode recommended values
TEMP="${TEMP:-1.0}"
TOP_K="${TOP_K:-20}"
TOP_P="${TOP_P:-0.95}"
MIN_P="${MIN_P:-0.0}"
REPEAT_PENALTY="${REPEAT_PENALTY:-1.0}"

# ── Sanity checks ───────────────────────────────────────────────────────────
if [[ ! -f "$BINARY" ]]; then
    echo "[ABORT] Binary not found: $BINARY"
    echo "        Build with: cmake --preset cpu-aocc && cmake --build build-cpu-aocc -j\$(nproc)"
    exit 1
fi
if [[ ! -f "$MODEL" ]]; then
    echo "[ABORT] Model not found: $MODEL"
    exit 1
fi

# ── Launch ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Qwen3.6-27B-Q4_K_M — CPU only (AOCC / Zen 4)"
echo "  NGL=0/64  CTX=$N_CTX  Threads=$N_THREADS"
echo "  temp=$TEMP  top_k=$TOP_K  top_p=$TOP_P"
echo "  Listening: http://$HOST:$PORT"
echo "========================================================"
echo ""

exec "$BINARY" \
    --model         "$MODEL" \
    --host          "$HOST" \
    --port          "$PORT" \
    --ctx-size      "$N_CTX" \
    --n-gpu-layers  0 \
    --threads       "$N_THREADS" \
    --parallel      "$N_PARALLEL" \
    --batch-size    "$N_BATCH" \
    --ubatch-size   "$N_UBATCH" \
    --temp          "$TEMP" \
    --top-k         "$TOP_K" \
    --top-p         "$TOP_P" \
    --min-p         "$MIN_P" \
    --repeat-penalty "$REPEAT_PENALTY" \
    --mmap \
    --jinja \
    --log-prefix \
    "$@"
