#!/usr/bin/env bash
# run-vulkan-amd-bench.sh
#
# Comparative AMD Vulkan benchmark: official llama.cpp Vulkan container vs
# custom AOCC 5.2.0 + Vulkan local build (build-vulkan-aocc/bin/llama-bench).
#
# GPU: AMD Radeon 780M iGPU (RADV PHOENIX / gfx1103), UMA architecture.
#      Shared system RAM — no discrete VRAM limit. ~24 GB total available.
#      Key use case: models up to ~20 GB run entirely in UMA.
#
# Engines:
#   A) container-vulkan : ghcr.io/ggml-org/llama.cpp:full-vulkan  (build 9487)
#   B) aocc-vulkan      : build-vulkan-aocc/bin/llama-bench        (build 9449)
#
# Test matrix:
#   7B  (4.4 GB,  ngl=99):          -fa 0,1  -pg 512,128 -pg 2048,256  -r 3
#   9B  (5.6 GB,  ngl=99):          -fa 0,1  -pg 512,128 -pg 2048,256  -r 3
#   27B (14 GB Q3_K_XL, ngl=99):    -fa 0,1  -pg 512,128               -r 3
#       All 27B layers fit in UMA — ngl=99 runs the full model on GPU.
#
# Output: bench_raw/YYYY-MM-DD/<model>_<engine>.jsonl + .log
#
# Usage:
#   ./run-vulkan-amd-bench.sh
#   SKIP_PULL=1 ./run-vulkan-amd-bench.sh   # skip container pull

set -uo pipefail
# NOTE: set -e intentionally omitted — a failed bench job logs the failure
# and continues; other models still run.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Model storage — two mount points
MODEL_ROOT_SSD="/mnt/512_ssd_internal/vai-llm-tei/llm-models"

DATE=$(date +%Y-%m-%d)
OUTDIR="${REPO_ROOT}/bench_raw/${DATE}"

# Container image.
# full-vulkan (build 9487) supports qwen35 arch and has radeon_icd.json (no x86_64 suffix).
LLAMA_VULKAN_IMAGE="${LLAMA_VULKAN_IMAGE:-ghcr.io/ggml-org/llama.cpp:full-vulkan}"
CONTAINER_TAG="container-vulkan"

# Local custom build (AOCC 5.2.0 + Vulkan, release)
LOCAL_BENCH="${REPO_ROOT}/build-vulkan-aocc/bin/llama-bench"
LOCAL_TAG="aocc-vulkan-release"

# Model paths
MODEL_7B="${MODEL_ROOT_SSD}/bartowski/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
MODEL_9B="${MODEL_ROOT_SSD}/bartowski/Tesslate_OmniCoder-9B-Q4_K_M.gguf"
MODEL_27B="${MODEL_ROOT_SSD}/unsloth/Qwen3.6-27B-UD-Q3_K_XL.gguf"

# AMD Vulkan isolation: RADV only, suppress CUDA/ROCR
# Note: ICD filename differs by container — full-vulkan uses radeon_icd.json
# (no x86_64 suffix); older b4927 used radeon_icd.x86_64.json.
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json
export CUDA_VISIBLE_DEVICES=""
export ROCR_VISIBLE_DEVICES=""
export HIP_VISIBLE_DEVICES=""

# AMD DRI device nodes on this system:
#   card1 / renderD129 = AMD Radeon 780M iGPU
#   card0 / renderD128 = NVIDIA RTX 4060 (do NOT pass these)
AMD_DRI_CARD=/dev/dri/card1
AMD_DRI_RENDER=/dev/dri/renderD129

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
BENCH_FAILURES=0

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
    echo "│  [Local build: ${LOCAL_BENCH}]"
    if [[ -x "${LOCAL_BENCH}" ]]; then
        ok "binary found"
        local list_out
        list_out=$("${LOCAL_BENCH}" --list-devices 2>&1 || true)
        if echo "${list_out}" | grep -qi "vulkan\|amd\|radeon\|780m\|radv"; then
            ok "AMD Vulkan device visible to local build"
            echo "${list_out}" | head -4 | while IFS= read -r l; do info "  $l"; done
        else
            warn "AMD Vulkan device not visible — check VK_ICD_FILENAMES"
        fi
    else
        fail "binary not found or not executable: ${LOCAL_BENCH}"
        info "Build: cmake -S . --preset vulkan-aocc && cmake --build build-vulkan-aocc -j\$(nproc)"
    fi

    # DRI device nodes
    echo "│"
    echo "│  [AMD DRI device nodes]"
    if [[ -e "${AMD_DRI_RENDER}" ]]; then
        ok "${AMD_DRI_RENDER} (AMD 780M render node)"
    else
        fail "${AMD_DRI_RENDER} not found — AMD GPU unavailable"
    fi
    if [[ -e "${AMD_DRI_CARD}" ]]; then
        ok "${AMD_DRI_CARD} (AMD 780M)"
    else
        warn "${AMD_DRI_CARD} not found (not critical if render node exists)"
    fi

    # Container image pull
    echo "│"
    echo "│  [Container image: ${LLAMA_VULKAN_IMAGE}]"
    if [[ "${SKIP_PULL:-0}" == "1" ]]; then
        warn "SKIP_PULL=1 — skipping pull"
        if ! podman image exists "${LLAMA_VULKAN_IMAGE}" 2>/dev/null; then
            fail "image not found locally and pull was skipped"
        else
            ok "image found locally (not re-pulled)"
        fi
    else
        info "Pulling ${LLAMA_VULKAN_IMAGE} ..."
        if podman pull "${LLAMA_VULKAN_IMAGE}" 2>&1 | tail -3; then
            ok "image ready"
        else
            fail "podman pull failed"
        fi
    fi

    # Verify container sees AMD GPU
    echo "│"
    echo "│  [Container GPU visibility]"
    local ctr_gpu
    ctr_gpu=$(podman run --rm \
        --entrypoint /bin/sh \
        --device "${AMD_DRI_CARD}" \
        --device "${AMD_DRI_RENDER}" \
        --security-opt label=disable \
        -e VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json \
        -e CUDA_VISIBLE_DEVICES="" \
        "${LLAMA_VULKAN_IMAGE}" \
        -c "/app/llama-bench -m /dev/null -p 1 -n 0 2>&1 | head -5" 2>&1 || echo "container run failed")
    if echo "${ctr_gpu}" | grep -qi "vulkan\|amd\|radeon\|780m\|radv\|gfx1103"; then
        ok "AMD Vulkan GPU visible inside container"
        echo "${ctr_gpu}" | head -4 | while IFS= read -r l; do info "  $l"; done
    else
        fail "AMD GPU not visible inside container — check DRI passthrough"
        echo "${ctr_gpu}" | head -5 | while IFS= read -r l; do info "  $l"; done
    fi

    echo "│"
    echo -e "└─────────────────────────────────────────────────────────────────────────────"

    if [[ "${PREFLIGHT_FAIL}" -ne 0 ]]; then
        echo -e "\n\e[31mERROR: pre-flight checks failed — fix the above issues before continuing.\e[0m\n"
        exit 1
    fi
}

# --------------------------------------------------------------------------- #
# Run llama-bench inside the container (one-shot podman run, not exec)
# $1 = host model path   $2 = output .jsonl path   $3+ = bench args
# --------------------------------------------------------------------------- #
run_container_bench() {
    local model_host_path=$1
    local outfile=$2
    shift 2
    local bench_args=("$@")
    local logfile="${outfile%.jsonl}.log"

    # Build volume mount args — mount whichever root the model lives under
    local vol_args=()
    if [[ "${model_host_path}" == "${MODEL_ROOT_SSD}"* ]]; then
        vol_args+=(-v "${MODEL_ROOT_SSD}:/models_ssd:ro")
        local model_container="/models_ssd/${model_host_path#"${MODEL_ROOT_SSD}"/}"
    elif [[ "${model_host_path}" == "${MODEL_ROOT_SSD}"* ]]; then
        vol_args+=(-v "${MODEL_ROOT_SSD}:/models_ext:ro")
        local model_container="/models_ext/${model_host_path#"${MODEL_ROOT_SSD}"/}"
    else
        echo -e "  ${C_FAIL} unknown model root for: ${model_host_path}"
        BENCH_FAILURES=$((BENCH_FAILURES + 1))
        return 1
    fi

    echo "  [container] $(basename "${outfile}")"

    local exit_code=0
    podman run --rm \
        --entrypoint /app/llama-bench \
        --device "${AMD_DRI_CARD}" \
        --device "${AMD_DRI_RENDER}" \
        --security-opt label=disable \
        "${vol_args[@]}" \
        -e VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json \
        -e CUDA_VISIBLE_DEVICES="" \
        -e ROCR_VISIBLE_DEVICES="" \
        -e HIP_VISIBLE_DEVICES="" \
        "${LLAMA_VULKAN_IMAGE}" \
            -m "${model_container}" \
            "${bench_args[@]}" \
            --progress \
            -o jsonl \
        2>&1 | tee "${logfile}" | grep --line-buffered '^{' > "${outfile}" || exit_code=$?

    local rows
    rows=$(wc -l < "${outfile}" 2>/dev/null || echo 0)
    if [[ "${exit_code}" -ne 0 ]] || [[ "${rows}" -eq 0 ]]; then
        echo -e "    ${C_FAIL} ${rows} rows written (exit ${exit_code}) — check $(basename "${logfile}")"
        BENCH_FAILURES=$((BENCH_FAILURES + 1))
    else
        echo "    → ${rows} JSONL rows written"
    fi
}

# --------------------------------------------------------------------------- #
# Run llama-bench from the local custom build
# $1 = host model path   $2 = output .jsonl path   $3+ = bench args
# --------------------------------------------------------------------------- #
run_local_bench() {
    local model_path=$1
    local outfile=$2
    shift 2
    local bench_args=("$@")
    local logfile="${outfile%.jsonl}.log"

    echo "  [local]     $(basename "${outfile}")"

    local exit_code=0
    "${LOCAL_BENCH}" \
        -m "${model_path}" \
        "${bench_args[@]}" \
        --progress \
        -o jsonl \
        2>&1 | tee "${logfile}" | grep --line-buffered '^{' > "${outfile}" || exit_code=$?

    local rows
    rows=$(wc -l < "${outfile}" 2>/dev/null || echo 0)
    if [[ "${exit_code}" -ne 0 ]] || [[ "${rows}" -eq 0 ]]; then
        echo -e "    ${C_FAIL} ${rows} rows written (exit ${exit_code}) — check $(basename "${logfile}")"
        BENCH_FAILURES=$((BENCH_FAILURES + 1))
    else
        echo "    → ${rows} JSONL rows written"
    fi
}

# --------------------------------------------------------------------------- #
# MAIN
# --------------------------------------------------------------------------- #
preflight

mkdir -p "${OUTDIR}"

echo -e "\n${C_HEAD}================================================================${C_RESET}"
echo -e "${C_HEAD}  Vulkan Benchmark: Container vs AOCC Custom Build${C_RESET}"
echo    "  Container : ${LLAMA_VULKAN_IMAGE}"
echo    "  Local     : ${LOCAL_BENCH}"
echo    "  GPU       : AMD Radeon 780M iGPU (RADV PHOENIX, UMA, gfx1103)"
echo    "  Output    : ${OUTDIR}"
echo    "  Started   : $(date -Iseconds)"
echo -e "${C_HEAD}================================================================${C_RESET}\n"

# --------------------------------------------------------------------------- #
# 7B: Qwen2.5-Coder-7B Q4_K_M  (4.4 GB — trivially fits in 24 GB UMA)
# --------------------------------------------------------------------------- #
echo -e "\n── ${C_HEAD}Model 1/3: qwen25-coder-7b-q4km${C_RESET} (4.4 GB, ngl=99) ──"
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
# 9B: Tesslate OmniCoder-9B Q4_K_M  (5.6 GB — fits easily in UMA)
# --------------------------------------------------------------------------- #
echo -e "\n── ${C_HEAD}Model 2/3: omnicoder-9b-q4km${C_RESET} (5.6 GB, ngl=99) ──"
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
# 27B: Qwen3.6-27B UD Q3_K_XL  (14 GB — key UMA use case, fits in shared RAM)
# ngl=99: all 64 layers on GPU via UMA. No VRAM overflow — CPU and GPU share
# the same physical RAM, so the model loads and runs entirely "on GPU".
# --------------------------------------------------------------------------- #
echo -e "\n── ${C_HEAD}Model 3/3: qwen3-27b-q3kxl${C_RESET} (14 GB Q3_K_XL, ngl=99, UMA) ──"
echo    "   All layers fit in shared RAM — primary Vulkan use case on 780M"
ARGS_27B=(-ngl 99 -fa "0,1" -pg "512,128" -r 3)

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
echo    "  Results   : ${OUTDIR}/"
echo    "  Finished  : $(date -Iseconds)"
if [[ "${BENCH_FAILURES}" -gt 0 ]]; then
    echo -e "  \e[31mFailed jobs: ${BENCH_FAILURES} — check .log files above\e[0m"
fi
echo -e "${C_HEAD}================================================================${C_RESET}\n"
echo    "Run comparison summary:"
echo    "  python3 ${REPO_ROOT}/summarize-vulkan-bench.py ${OUTDIR}"
echo    ""
echo    "Individual result files:"
for f in "${OUTDIR}"/*.jsonl; do
    rows=$(wc -l < "$f" 2>/dev/null || echo "?")
    printf "  %-65s  %s rows\n" "$(basename "$f")" "${rows}"
done
