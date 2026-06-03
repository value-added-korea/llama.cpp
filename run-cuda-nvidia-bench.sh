#!/usr/bin/env bash
# run-cuda-nvidia-bench.sh
#
# Comparative NVIDIA CUDA benchmark: official llama.cpp container vs custom
# AOCC 5.2.0 + CUDA 13.3 local build.
#
# Engines:
#   A) container-b9449  : ghcr.io/ggerganov/llama.cpp:full-cuda-b9449
#   B) aocc-cuda13-reldbg: build-cuda-aocc-reldbg/bin/llama-bench
#
# Test matrix (llama-bench multi-value syntax — one call per model per engine):
#   7B  (4.4GB, full GPU):         -ngl 99    -fa 0,1  -pg 512,128 -pg 2048,256  -r 3
#   9B  (5.6GB, full GPU):         -ngl 99    -fa 0,1  -pg 512,128 -pg 2048,256  -r 3
#   27B (14GB, CPU+GPU split):     -ngl 20,35 -fa 0,1  -pg 512,128               -r 3
#
# Output: bench_raw/YYYY-MM-DD/<model>_<engine>.jsonl + .log
#
# Usage:
#   ./run-cuda-nvidia-bench.sh
#   LLAMA_IMAGE=ghcr.io/ggerganov/llama.cpp:full-cuda-b9450 ./run-cuda-nvidia-bench.sh
#   SKIP_PULL=1 ./run-cuda-nvidia-bench.sh   # skip container pull (image already local)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_ROOT="/mnt/512_ssd_internal/vai-llm-tei/llm-models"
DATE=$(date +%Y-%m-%d)
OUTDIR="${REPO_ROOT}/bench_raw/${DATE}"

# Container image. Change LLAMA_IMAGE env var to override.
# Registry moved from ggerganov → ggml-org. Tag b9445 is the release tag
# in this repo; 4 later commits are CI/SYCL-only and were never published.
# The inference code is identical between container and local build.
LLAMA_IMAGE="${LLAMA_IMAGE:-ghcr.io/ggml-org/llama.cpp:full-cuda-b9445}"
CONTAINER_TAG="container-b9445"

# Local custom build (AOCC 5.2.0 + CUDA 13.3, reldbg)
LOCAL_BENCH="${REPO_ROOT}/build-cuda-aocc-reldbg/bin/llama-bench"
LOCAL_TAG="aocc-cuda13-reldbg"

# Model paths on the host
MODEL_7B="${MODEL_ROOT}/bartowski/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
MODEL_9B="${MODEL_ROOT}/bartowski/Tesslate_OmniCoder-9B-Q4_K_M.gguf"
MODEL_27B="${MODEL_ROOT}/unsloth/Qwen3.6-27B-UD-Q3_K_XL.gguf"

# Ensure NVIDIA GPU is visible; clear any AOCC/ROCm env that might bleed from shell
export CUDA_VISIBLE_DEVICES=0
export ROCR_VISIBLE_DEVICES=""
export HIP_VISIBLE_DEVICES=""

# --------------------------------------------------------------------------- #
# Colour helpers
# --------------------------------------------------------------------------- #
C_OK="\e[32m[OK]\e[0m"
C_FAIL="\e[31m[FAIL]\e[0m"
C_WARN="\e[33m[WARN]\e[0m"
C_INFO="\e[36m[INFO]\e[0m"
C_HEAD="\e[1m"
C_RESET="\e[0m"

ok()   { echo -e "  ${C_OK}   $*"; }
fail() { echo -e "  ${C_FAIL} $*"; PREFLIGHT_FAIL=1; }
warn() { echo -e "  ${C_WARN} $*"; }
info() { echo -e "  ${C_INFO} $*"; }

PREFLIGHT_FAIL=0

# --------------------------------------------------------------------------- #
# PRE-FLIGHT
# --------------------------------------------------------------------------- #
preflight() {
    echo -e "\n${C_HEAD}┌─ PRE-FLIGHT ────────────────────────────────────────────────────────────${C_RESET}"

    # Models
    echo "│"
    echo "│  [Models]"
    for m in "${MODEL_7B}" "${MODEL_9B}" "${MODEL_27B}"; do
        if [[ -f "$m" ]]; then
            local sz
            sz=$(du -sh "$m" | cut -f1)
            ok "$(basename "$m") (${sz})"
        else
            fail "model not found: $m"
        fi
    done

    # Local binary
    echo "│"
    echo "│  [Local build]"
    if [[ -x "${LOCAL_BENCH}" ]]; then
        ok "${LOCAL_BENCH}"
        # Verify it has CUDA support
        local list_out
        list_out=$("${LOCAL_BENCH}" --list-devices 2>&1 || true)
        if echo "${list_out}" | grep -qi "cuda\|rtx\|nvidia\|4060"; then
            ok "CUDA device visible to local build"
            echo "${list_out}" | head -5 | while IFS= read -r l; do info "  $l"; done
        else
            warn "CUDA device not visible in --list-devices output (check CUDA_VISIBLE_DEVICES)"
        fi
    else
        fail "binary not found or not executable: ${LOCAL_BENCH}"
        info "Build first: cmake -S . --preset cuda-aocc-reldbg && cmake --build build-cuda-aocc-reldbg -j\$(nproc)"
    fi

    # NVIDIA GPU
    echo "│"
    echo "│  [NVIDIA GPU]"
    local gpu_info
    gpu_info=$(nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader 2>/dev/null || echo "nvidia-smi failed")
    info "${gpu_info}"

    # CDI check — quick test with a lightweight container
    echo "│"
    echo "│  [NVIDIA CDI passthrough]"
    if [[ -f /etc/cdi/nvidia.yaml ]]; then
        ok "CDI spec: /etc/cdi/nvidia.yaml"
    else
        warn "CDI spec not found at /etc/cdi/nvidia.yaml"
        info "Generate: sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
    fi

    # Container image — pull unless skipped
    echo "│"
    echo "│  [Container image: ${LLAMA_IMAGE}]"
    if [[ "${SKIP_PULL:-0}" == "1" ]]; then
        warn "SKIP_PULL=1 — skipping pull"
        if ! podman image exists "${LLAMA_IMAGE}" 2>/dev/null; then
            fail "image not found locally and pull was skipped"
        else
            ok "image found locally (not re-pulled)"
        fi
    else
        info "Pulling ${LLAMA_IMAGE} ..."
        if podman pull "${LLAMA_IMAGE}" 2>&1 | tail -3; then
            ok "image ready"
        else
            fail "podman pull failed — check network or try: LLAMA_IMAGE=... ./run-cuda-nvidia-bench.sh"
        fi
    fi

    # Verify container sees the GPU
    echo "│"
    echo "│  [Container GPU visibility]"
    local ctr_gpu
    ctr_gpu=$(podman run --rm \
        --entrypoint /app/llama-bench \
        --device nvidia.com/gpu=all \
        --security-opt label=disable \
        -e CUDA_VISIBLE_DEVICES=0 \
        "${LLAMA_IMAGE}" \
        --list-devices 2>&1 | head -10 || echo "container run failed")
    if echo "${ctr_gpu}" | grep -qi "cuda\|rtx\|nvidia\|4060"; then
        ok "GPU visible inside container"
        echo "${ctr_gpu}" | head -5 | while IFS= read -r l; do info "  $l"; done
    else
        fail "GPU not visible inside container — check CDI or image CUDA support"
        echo "${ctr_gpu}" | head -8 | while IFS= read -r l; do info "  $l"; done
    fi

    echo "│"
    echo -e "└─────────────────────────────────────────────────────────────────────────────"

    if [[ "${PREFLIGHT_FAIL}" -ne 0 ]]; then
        echo -e "\n\e[31mERROR: pre-flight checks failed — fix the above issues before continuing.\e[0m\n"
        exit 1
    fi
}

# --------------------------------------------------------------------------- #
# Run llama-bench inside the container
# --------------------------------------------------------------------------- #
run_container_bench() {
    local model_host_path=$1
    local outfile=$2
    shift 2
    local bench_args=("$@")

    # Translate host path to container path: MODEL_ROOT → /models
    local model_container="/models/${model_host_path#"${MODEL_ROOT}"/}"
    local logfile="${outfile%.jsonl}.log"

    echo "  [container] $(basename "${outfile}")"

    podman run --rm \
        --entrypoint /app/llama-bench \
        --device nvidia.com/gpu=all \
        --security-opt label=disable \
        -v "${MODEL_ROOT}:/models:ro" \
        -e CUDA_VISIBLE_DEVICES=0 \
        -e ROCR_VISIBLE_DEVICES="" \
        -e HIP_VISIBLE_DEVICES="" \
        "${LLAMA_IMAGE}" \
            -m "${model_container}" \
            "${bench_args[@]}" \
            --progress \
            -o jsonl \
        2>&1 | tee "${logfile}" | grep --line-buffered '^{' > "${outfile}"

    local rows
    rows=$(wc -l < "${outfile}" 2>/dev/null || echo 0)
    echo "    → ${rows} JSONL rows written"
}

# --------------------------------------------------------------------------- #
# Run llama-bench from the local custom build
# --------------------------------------------------------------------------- #
run_local_bench() {
    local model_path=$1
    local outfile=$2
    shift 2
    local bench_args=("$@")

    local logfile="${outfile%.jsonl}.log"

    echo "  [local]     $(basename "${outfile}")"

    "${LOCAL_BENCH}" \
        -m "${model_path}" \
        "${bench_args[@]}" \
        --progress \
        -o jsonl \
        2>&1 | tee "${logfile}" | grep --line-buffered '^{' > "${outfile}"

    local rows
    rows=$(wc -l < "${outfile}" 2>/dev/null || echo 0)
    echo "    → ${rows} JSONL rows written"
}

# --------------------------------------------------------------------------- #
# MAIN
# --------------------------------------------------------------------------- #
preflight

mkdir -p "${OUTDIR}"

echo -e "\n${C_HEAD}================================================================${C_RESET}"
echo -e "${C_HEAD}  CUDA Benchmark: Container vs AOCC Custom Build${C_RESET}"
echo    "  Container : ${LLAMA_IMAGE}"
echo    "  Local     : ${LOCAL_BENCH}"
echo    "  Output    : ${OUTDIR}"
echo    "  Started   : $(date -Iseconds)"
echo -e "${C_HEAD}================================================================${C_RESET}\n"

# --------------------------------------------------------------------------- #
# 7B: Qwen2.5-Coder-7B Q4_K_M (4.4 GB — fits fully in RTX 4060 8GB VRAM)
# Test: both FA states, two pp+tg sizes
# --------------------------------------------------------------------------- #
echo -e "\n── ${C_HEAD}Model 1/3: qwen25-coder-7b-q4km${C_RESET} (4.4GB, full GPU, ngl=99) ──"
ARGS_7B=(-ngl 99 -fa "0,1" -pg "512,128" -pg "2048,256" -r 3)

run_container_bench \
    "${MODEL_7B}" \
    "${OUTDIR}/qwen25-coder-7b-q4km_${CONTAINER_TAG}.jsonl" \
    "${ARGS_7B[@]}"

run_local_bench \
    "${MODEL_7B}" \
    "${OUTDIR}/qwen25-coder-7b-q4km_${LOCAL_TAG}.jsonl" \
    "${ARGS_7B[@]}"

# --------------------------------------------------------------------------- #
# 9B: Tesslate OmniCoder-9B Q4_K_M (5.6 GB — fits in VRAM but leaves <2GB margin)
# Test: same as 7B
# --------------------------------------------------------------------------- #
echo -e "\n── ${C_HEAD}Model 2/3: omnicoder-9b-q4km${C_RESET} (5.6GB, full GPU, ngl=99) ──"
ARGS_9B=(-ngl 99 -fa "0,1" -pg "512,128" -pg "2048,256" -r 3)

run_container_bench \
    "${MODEL_9B}" \
    "${OUTDIR}/omnicoder-9b-q4km_${CONTAINER_TAG}.jsonl" \
    "${ARGS_9B[@]}"

run_local_bench \
    "${MODEL_9B}" \
    "${OUTDIR}/omnicoder-9b-q4km_${LOCAL_TAG}.jsonl" \
    "${ARGS_9B[@]}"

# --------------------------------------------------------------------------- #
# 27B: Qwen3.6-27B Q3_K_XL (14 GB — intentionally exceeds VRAM, forces CPU+GPU split)
# ngl=20: ~5GB on GPU (comfortable), ngl=35: ~9GB (VRAM overflow into system RAM)
# Smaller pp context only — CPU offload makes long-context prompts very slow
# --------------------------------------------------------------------------- #
echo -e "\n── ${C_HEAD}Model 3/3: qwen3-27b-q3kxl${C_RESET} (14GB, CPU+GPU split, ngl=20,35) ──"
echo    "   ngl=20 → ~5GB on GPU (comfortable); ngl=35 → ~9GB (VRAM spill into RAM)"
ARGS_27B=(-ngl "20,35" -fa "0,1" -pg "512,128" -r 3)

run_container_bench \
    "${MODEL_27B}" \
    "${OUTDIR}/qwen3-27b-q3kxl_${CONTAINER_TAG}.jsonl" \
    "${ARGS_27B[@]}"

run_local_bench \
    "${MODEL_27B}" \
    "${OUTDIR}/qwen3-27b-q3kxl_${LOCAL_TAG}.jsonl" \
    "${ARGS_27B[@]}"

# --------------------------------------------------------------------------- #
# DONE
# --------------------------------------------------------------------------- #
echo -e "\n${C_HEAD}================================================================${C_RESET}"
echo -e "${C_HEAD}  All benchmarks complete${C_RESET}"
echo    "  Results : ${OUTDIR}/"
echo    "  Finished: $(date -Iseconds)"
echo -e "${C_HEAD}================================================================${C_RESET}\n"
echo    "Run comparison summary:"
echo    "  python3 ${REPO_ROOT}/summarize-cuda-bench.py ${OUTDIR}"
echo    ""
echo    "Individual result files:"
for f in "${OUTDIR}"/*.jsonl; do
    rows=$(wc -l < "$f" 2>/dev/null || echo "?")
    printf "  %-60s  %s rows\n" "$(basename "$f")" "${rows}"
done
