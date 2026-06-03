#!/usr/bin/env bash
# Comparative benchmark across three llama.cpp builds:
#   build-cpu-aocc    (CPU only, AOCC compiler)
#   build-vulkan-aocc (Vulkan iGPU, AOCC compiler)
#   build-rocm-aocc   (ROCm/HIP iGPU, AOCC compiler)
#
# Usage:
#   bash run_bench_compare.sh [MODEL_PATH] [OUTPUT_JSON]
#
# Defaults:
#   MODEL_PATH  = /mnt/512_ssd_internal/vai-llm-tei/llm-models/qwen2.5-coder-7b-instruct-q4_k_m.gguf
#   OUTPUT_JSON = bench_results.json

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODEL="${1:-/mnt/512_ssd_internal/vai-llm-tei/llm-models/qwen2.5-coder-7b-instruct-q4_k_m.gguf}"
OUTPUT_JSON="${2:-${REPO_ROOT}/bench_results.json}"
RESULTS_DIR="${REPO_ROOT}/bench_raw"
REPETITIONS="${REPETITIONS:-20}"
N_PROMPT="${N_PROMPT:-512}"
N_GEN="${N_GEN:-128}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"

# --------------------------------------------------------------------------- #
# GPU device isolation — AMD 780M only, NVIDIA RTX 4060 permanently excluded
# --------------------------------------------------------------------------- #
# Vulkan: restrict ICD loader to AMD RADV; prevents NVIDIA device enumeration
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json
# ROCm: pin to device 0 (AMD 780M)
# HSA_OVERRIDE_GFX_VERSION is intentionally NOT set: gfx1103 is natively
# supported by ROCm 7.13 and overriding the GFX version causes GPU hangs.
export ROCR_VISIBLE_DEVICES=0
export HIP_VISIBLE_DEVICES=0
# CUDA: dead path — ensure NVIDIA GPU is invisible to any CUDA runtime
export CUDA_VISIBLE_DEVICES=""
unset  CUDA_DEVICE_ORDER

# --------------------------------------------------------------------------- #
# Build definitions: label | binary | n-gpu-layers | expected backend string
# --------------------------------------------------------------------------- #
declare -a BUILD_LABELS=( "cpu-aocc" "vulkan-aocc" "rocm-aocc" )

declare -A BUILD_BINS=(
    ["cpu-aocc"]="${REPO_ROOT}/build-cpu-aocc/bin/llama-bench"
    ["vulkan-aocc"]="${REPO_ROOT}/build-vulkan-aocc/bin/llama-bench"
    ["rocm-aocc"]="${REPO_ROOT}/build-rocm-aocc/bin/llama-bench"
)

declare -A BUILD_NGL=(
    ["cpu-aocc"]="0"
    ["vulkan-aocc"]="999"
    ["rocm-aocc"]="999"   # adjusted dynamically — see compute_safe_rocm_ngl()
)

# String that must appear in the "backends" field of every jsonl record.
declare -A BUILD_EXPECTED_BACKEND=(
    ["cpu-aocc"]="CPU"
    ["vulkan-aocc"]="Vulkan"
    ["rocm-aocc"]="ROCm"
)

# --------------------------------------------------------------------------- #
# Helper: coloured pass/fail tags
# --------------------------------------------------------------------------- #
PASS="\e[32m[PASS]\e[0m"
FAIL="\e[31m[FAIL]\e[0m"
INFO="\e[36m[INFO]\e[0m"

pass() { echo -e "  ${PASS} $*"; }
fail() { echo -e "  ${FAIL} $*"; GLOBAL_FAIL=1; }
info() { echo -e "  ${INFO} $*"; }

GLOBAL_FAIL=0

# --------------------------------------------------------------------------- #
# ROCm GPU health check — detect hung/corrupt GPU state before benchmarking
# --------------------------------------------------------------------------- #
# An iGPU hang (GPU Hang kernel exception) leaves the device in a bad state
# for the rest of the session.  There is no PCI reset path for an iGPU; the
# only recovery is to log out / restart the display manager.  This function
# runs a lightweight ROCm probe and returns 1 if the GPU is unresponsive.
rocm_gpu_healthy() {
    local bin="${BUILD_BINS[rocm-aocc]}"
    local probe_out
    # --list-devices triggers ROCm init without loading a model; if the GPU
    # is hung, this will either stall or print an HSA exception.
    probe_out=$(timeout 15 "${bin}" --list-devices 2>&1 || true)
    if echo "${probe_out}" | grep -qi "gpu hang\|hsa.*exception\|hw exception\|signal 6\|signal 11\|aborted"; then
        return 1
    fi
    if ! echo "${probe_out}" | grep -qi "gfx1103\|Radeon\|ROCm"; then
        return 1
    fi
    return 0
}

# --------------------------------------------------------------------------- #
# ROCm NGL: compute safe layer offload count from available VRAM
# --------------------------------------------------------------------------- #
# The 780M's HIP backend reports a hard cap of ~2 GB usable VRAM (the
# ggml_backend_cuda_get_available_uma_memory UMA limit for iGPUs).  Loading a
# 4–5 GB model with ngl=999 exceeds this and causes a GPU hang.  This
# function queries the real cap at runtime and calculates the largest NGL that
# keeps weight tensors within the budget.
compute_safe_rocm_ngl() {
    local bin="${BUILD_BINS[rocm-aocc]}"
    local model_path="$1"

    # Available VRAM in MiB as reported by llama-bench --list-devices
    local avail_mib
    avail_mib=$("${bin}" --list-devices 2>&1 | \
                grep -oP '\d+(?= MiB free\))' | head -1 || echo 0)
    avail_mib="${avail_mib:-0}"

    if [[ "${avail_mib}" -le 512 ]]; then
        # Not enough headroom for KV cache — CPU only
        echo 0; return
    fi

    # Reserve 512 MiB for KV cache + runtime overhead
    local usable_mib=$(( avail_mib - 512 ))

    # Model size in MiB
    local model_bytes
    model_bytes=$(stat -c%s "${model_path}" 2>/dev/null || echo 0)
    local model_mib=$(( model_bytes / 1048576 ))

    if [[ "${model_mib}" -le 0 ]]; then
        echo 999; return
    fi

    # Approximate NGL: scale by (usable / total) across ~30 total weight groups
    # (28 transformer layers + embeddings/output/norm).  Conservative on purpose.
    local ngl=$(( usable_mib * 30 / model_mib ))
    [[ "${ngl}" -gt 999 ]] && ngl=999
    [[ "${ngl}" -lt 0 ]]   && ngl=0
    echo "${ngl}"
}

# --------------------------------------------------------------------------- #
# PRE-FLIGHT: system-level device isolation
# --------------------------------------------------------------------------- #
preflight_device_isolation() {
    echo ""
    echo "┌─ PRE-FLIGHT: device isolation ──────────────────────────────────────────────"

    # --- Vulkan ICD file present? ---
    echo "│"
    echo "│  [Vulkan ICD]"
    if [[ -f "${VK_ICD_FILENAMES}" ]]; then
        pass "ICD file exists: ${VK_ICD_FILENAMES}"
    else
        fail "ICD file missing: ${VK_ICD_FILENAMES}"
    fi

    # --- vulkaninfo: enumerate devices visible under RADV-only ICD ---
    echo "│"
    echo "│  [Vulkan devices visible to llama-bench]"
    local vk_devices
    vk_devices=$(VK_ICD_FILENAMES="${VK_ICD_FILENAMES}" \
        vulkaninfo 2>/dev/null | grep -E "GPU id" || true)
    if [[ -z "${vk_devices}" ]]; then
        fail "vulkaninfo returned no devices — check VK_ICD_FILENAMES"
    else
        echo "${vk_devices}" | while IFS= read -r line; do info "${line}"; done
        if echo "${vk_devices}" | grep -qi "nvidia\|rtx\|gtx\|quadro"; then
            fail "NVIDIA device visible in Vulkan enumeration — ABORT"
        else
            pass "No NVIDIA device in Vulkan enumeration"
        fi
        if echo "${vk_devices}" | grep -qi "amd\|radeon\|radv"; then
            pass "AMD 780M visible in Vulkan enumeration"
        else
            fail "AMD device not found in Vulkan enumeration"
        fi
    fi

    # --- ROCm: rocminfo ---
    echo "│"
    echo "│  [ROCm devices visible (ROCR_VISIBLE_DEVICES=${ROCR_VISIBLE_DEVICES}, HSA_OVERRIDE_GFX_VERSION unset)]"
    local rocm_out
    rocm_out=$(ROCR_VISIBLE_DEVICES="${ROCR_VISIBLE_DEVICES}" \
        rocminfo 2>/dev/null | grep -E "^\s*(Name:|ISA\s|amdgcn)" || true)
    if [[ -z "${rocm_out}" ]]; then
        fail "rocminfo returned no devices"
    else
        echo "${rocm_out}" | while IFS= read -r line; do info "  ${line}"; done
        if echo "${rocm_out}" | grep -q "gfx1103"; then
            pass "gfx1103 (AMD 780M) confirmed in ROCm device list"
        else
            fail "gfx1103 not found — wrong device or ROCR_VISIBLE_DEVICES misconfigured"
        fi
        if ROCR_VISIBLE_DEVICES="${ROCR_VISIBLE_DEVICES}" \
               rocminfo 2>/dev/null | grep -qi "nvidia\|cuda"; then
            fail "NVIDIA/CUDA reference in rocminfo output — ABORT"
        else
            pass "No NVIDIA/CUDA reference in rocminfo output"
        fi
    fi

    # --- CUDA runtime killed? ---
    echo "│"
    echo "│  [CUDA/NVIDIA runtime isolation]"
    if [[ "${CUDA_VISIBLE_DEVICES}" == "" ]]; then
        pass "CUDA_VISIBLE_DEVICES=\"\" — CUDA runtime sees zero devices"
    else
        fail "CUDA_VISIBLE_DEVICES is not empty: '${CUDA_VISIBLE_DEVICES}'"
    fi
    if nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | grep -q .; then
        # Driver is installed (dual-GPU laptop); confirm CUDA is masked.
        local cuda_test
        cuda_test=$(CUDA_VISIBLE_DEVICES="" nvidia-smi -L 2>/dev/null || true)
        info "nvidia-smi (driver installed): ${cuda_test:-not found}"
        info "CUDA runtime masked by CUDA_VISIBLE_DEVICES=\"\" — builds compiled GGML_CUDA=OFF"
    else
        pass "nvidia-smi: no GPU listed — NVIDIA fully isolated"
    fi

    echo "│"
    echo "└─────────────────────────────────────────────────────────────────────────────"
}

# --------------------------------------------------------------------------- #
# PRE-FLIGHT: per-build cmake cache + llama-bench --list-devices
# --------------------------------------------------------------------------- #
preflight_build_checks() {
    echo ""
    echo "┌─ PRE-FLIGHT: build cache + device list ─────────────────────────────────────"

    for label in "${BUILD_LABELS[@]}"; do
        local bin="${BUILD_BINS[$label]}"
        local build_dir="${REPO_ROOT}/build-${label}"
        local cache="${build_dir}/CMakeCache.txt"
        local expected_backend="${BUILD_EXPECTED_BACKEND[$label]}"

        echo "│"
        echo "│  ── [${label}] ──"

        # binary present?
        if [[ -x "${bin}" ]]; then
            pass "binary: ${bin}"
        else
            fail "binary not found: ${bin}"; continue
        fi

        # cmake cache: GGML_CUDA must be OFF
        if [[ -f "${cache}" ]]; then
            local cuda_val
            cuda_val=$(grep "^GGML_CUDA:BOOL=" "${cache}" | cut -d= -f2 || echo "?")
            if [[ "${cuda_val}" == "OFF" ]]; then
                pass "cmake cache: GGML_CUDA=OFF"
            else
                fail "cmake cache: GGML_CUDA=${cuda_val} — CUDA enabled in build!"
            fi

            # backend-specific cache checks
            case "${label}" in
                rocm-aocc)
                    local hip_val
                    hip_val=$(grep "^GGML_HIP:BOOL=" "${cache}" | cut -d= -f2 || echo "?")
                    # cmake may store the target under GPU_TARGETS or AMDGPU_TARGETS
                    local gpu_target
                    gpu_target=$(grep -E "^(GPU_TARGETS|AMDGPU_TARGETS):" "${cache}" \
                                 | cut -d= -f2 | tr '\n' ',' | sed 's/,$//' || echo "?")
                    if [[ "${hip_val}" == "ON" ]]; then
                        pass "cmake cache: GGML_HIP=ON"
                    else
                        fail "cmake cache: GGML_HIP=${hip_val}"
                    fi
                    if [[ "${gpu_target}" == *"gfx1103"* ]]; then
                        pass "cmake cache: GPU target=${gpu_target}"
                    else
                        fail "cmake cache: GPU target='${gpu_target}' — gfx1103 missing"
                    fi
                    ;;
                vulkan-aocc)
                    local vk_val
                    vk_val=$(grep "^GGML_VULKAN:BOOL=" "${cache}" | cut -d= -f2 || echo "?")
                    if [[ "${vk_val}" == "ON" ]]; then
                        pass "cmake cache: GGML_VULKAN=ON"
                    else
                        fail "cmake cache: GGML_VULKAN=${vk_val}"
                    fi
                    ;;
                cpu-aocc)
                    local vk_val hip_val
                    vk_val=$(grep "^GGML_VULKAN:BOOL=" "${cache}" | cut -d= -f2 || echo "?")
                    hip_val=$(grep "^GGML_HIP:BOOL=" "${cache}" | cut -d= -f2 || echo "?")
                    if [[ "${vk_val}" == "OFF" && "${hip_val}" == "OFF" ]]; then
                        pass "cmake cache: GGML_VULKAN=OFF GGML_HIP=OFF (CPU only)"
                    else
                        fail "cmake cache: GGML_VULKAN=${vk_val} GGML_HIP=${hip_val}"
                    fi
                    ;;
            esac
        else
            fail "cmake cache not found: ${cache}"
        fi

        # llama-bench --list-devices: confirm device selection
        echo "│    llama-bench --list-devices:"
        local list_out
        list_out=$("${bin}" --list-devices 2>&1 || true)
        echo "${list_out}" | while IFS= read -r line; do info "    ${line}"; done

        # rocm-aocc: confirm gfx1103 in device list; no NVIDIA
        if [[ "${label}" == "rocm-aocc" ]]; then
            if echo "${list_out}" | grep -qi "gfx1103\|780M\|Radeon"; then
                pass "--list-devices: AMD 780M (gfx1103) visible"
            else
                fail "--list-devices: AMD 780M not found"
            fi
        fi
        # vulkan-aocc: confirm AMD; confirm no NVIDIA
        if [[ "${label}" == "vulkan-aocc" ]]; then
            if echo "${list_out}" | grep -qi "amd\|radeon\|radv\|780M"; then
                pass "--list-devices: AMD 780M visible"
            else
                fail "--list-devices: AMD 780M not found"
            fi
        fi
        # any build: NVIDIA must never appear
        if echo "${list_out}" | grep -qi "nvidia\|rtx\|gtx"; then
            fail "--list-devices: NVIDIA device visible — ABORT"
        else
            pass "--list-devices: no NVIDIA device"
        fi
    done

    echo "│"
    echo "└─────────────────────────────────────────────────────────────────────────────"
}

# --------------------------------------------------------------------------- #
# POST-BENCH: verify jsonl logs confirm expected backend and no NVIDIA
# --------------------------------------------------------------------------- #
postbench_verify() {
    local label="$1"
    local raw_file="$2"
    local log_file="${raw_file}.log"
    local expected_backend="${BUILD_EXPECTED_BACKEND[$label]}"

    echo "│  ── [${label}] post-bench verification ──"

    # backend field in each jsonl record
    if [[ -f "${raw_file}" ]] && [[ -s "${raw_file}" ]]; then
        local wrong_backend=0
        while IFS= read -r line; do
            [[ -z "${line}" ]] && continue
            local actual_backend
            actual_backend=$(echo "${line}" | grep -oP '"backends"\s*:\s*"\K[^"]+' || echo "?")
            if [[ "${actual_backend}" != *"${expected_backend}"* ]]; then
                fail "record backend='${actual_backend}', expected '${expected_backend}'"
                wrong_backend=1
            fi
        done < "${raw_file}"
        if [[ "${wrong_backend}" -eq 0 ]]; then
            pass "all jsonl records: backends contains '${expected_backend}'"
        fi
    else
        fail "jsonl output missing or empty: ${raw_file}"
    fi

    # log file: NVIDIA must not appear in the llama-bench output
    if [[ -f "${log_file}" ]]; then
        local nvidia_hits
        nvidia_hits=$(grep -ci "nvidia\|rtx 40\|cuda device" "${log_file}" || true)
        if [[ "${nvidia_hits}" -gt 0 ]]; then
            fail "NVIDIA reference in bench log (${nvidia_hits} hit(s)) — check ${log_file}"
        else
            pass "no NVIDIA reference in bench log"
        fi

        # show device lines from log for confirmation
        local device_lines
        device_lines=$(grep -E "ggml_vulkan|ggml_cuda_init|ggml_hip|Device [0-9]|backend" \
            "${log_file}" 2>/dev/null | head -5 || true)
        if [[ -n "${device_lines}" ]]; then
            echo "${device_lines}" | while IFS= read -r line; do info "    ${line}"; done
        fi
    else
        fail "bench log missing: ${log_file}"
    fi
}

# --------------------------------------------------------------------------- #
# MAIN
# --------------------------------------------------------------------------- #

# --- pre-flight ---
if [[ ! -f "${MODEL}" ]]; then
    echo "ERROR: model file not found: ${MODEL}" >&2
    exit 1
fi
for label in "${BUILD_LABELS[@]}"; do
    bin="${BUILD_BINS[$label]}"
    if [[ ! -x "${bin}" ]]; then
        echo "ERROR: binary not found or not executable: ${bin}" >&2
        exit 1
    fi
done

preflight_device_isolation
preflight_build_checks

if [[ "${GLOBAL_FAIL}" -ne 0 ]]; then
    echo ""
    echo -e "\e[31mERROR: pre-flight checks failed — aborting benchmark.\e[0m"
    echo "       Review the [FAIL] items above before proceeding."
    exit 1
fi

mkdir -p "${RESULTS_DIR}"

# Adjust ROCm NGL now that we know the binaries exist and pre-flight passed.
# The 780M iGPU has a hard ~2 GB VRAM cap in llama.cpp's HIP backend; computing
# a safe NGL prevents the GPU hang that occurs with full (ngl=999) offload of
# models larger than the cap.
_rocm_ngl=$(compute_safe_rocm_ngl "${MODEL}")
BUILD_NGL["rocm-aocc"]="${_rocm_ngl}"
echo ""
echo -e "  \e[36m[INFO]\e[0m ROCm safe NGL computed: ${_rocm_ngl} layers" \
    "(model=$(( $(stat -c%s "${MODEL}") / 1048576 )) MiB, available=$(
        build-rocm-aocc/bin/llama-bench --list-devices 2>&1 | \
        grep -oP '\d+(?= MiB free\))' | head -1) MiB free)"

# --- benchmark loop ---
echo ""
echo "================================================================"
echo "  llama.cpp comparative benchmark"
echo "  Model      : ${MODEL}"
echo "  Repetitions: ${REPETITIONS}"
echo "  n-prompt   : ${N_PROMPT}  n-gen: ${N_GEN}"
echo "  Started    : $(date -Iseconds)"
echo "================================================================"

for label in "${BUILD_LABELS[@]}"; do
    bin="${BUILD_BINS[$label]}"
    ngl="${BUILD_NGL[$label]}"
    raw_file="${RESULTS_DIR}/${label}.jsonl"

    echo ""
    echo "--- [${label}] starting (ngl=${ngl}) ---"
    echo "    binary : ${bin}"
    echo "    output : ${raw_file}"
    echo ""

    # ROCm-specific health check: skip rather than hang if the GPU is stuck.
    if [[ "${label}" == "rocm-aocc" ]]; then
        if ! rocm_gpu_healthy; then
            echo "    [SKIP] ROCm GPU is unresponsive (prior GPU hang?)."
            echo "           Log out and back in to clear the iGPU hang state, then re-run."
            GLOBAL_FAIL=1
            continue
        fi
    fi

    "${bin}" \
        --model        "${MODEL}" \
        --n-prompt     "${N_PROMPT}" \
        --n-gen        "${N_GEN}" \
        --batch-size   "${BATCH_SIZE}" \
        --ubatch-size  "${UBATCH_SIZE}" \
        --repetitions  "${REPETITIONS}" \
        --n-gpu-layers "${ngl}" \
        --output jsonl \
        2>&1 | tee "${raw_file}.log" | grep --line-buffered '^{' > "${raw_file}"

    line_count=$(wc -l < "${raw_file}" || echo 0)
    echo "    captured ${line_count} jsonl record(s)"
    echo "--- [${label}] done ---"
done

# --- post-bench verification ---
echo ""
echo "┌─ POST-BENCH: backend + device verification ─────────────────────────────────"
for label in "${BUILD_LABELS[@]}"; do
    raw_file="${RESULTS_DIR}/${label}.jsonl"
    echo "│"
    postbench_verify "${label}" "${raw_file}"
done
echo "│"
echo "└─────────────────────────────────────────────────────────────────────────────"

if [[ "${GLOBAL_FAIL}" -ne 0 ]]; then
    echo ""
    echo -e "\e[31mWARNING: post-bench checks flagged issues — review output above.\e[0m"
fi

# --- merge ---
echo ""
echo "Merging results into ${OUTPUT_JSON} ..."

python3 "${REPO_ROOT}/merge_bench_results.py" \
    --results-dir "${RESULTS_DIR}" \
    --labels      "${BUILD_LABELS[@]}" \
    --model       "${MODEL}" \
    --output      "${OUTPUT_JSON}"

echo ""
echo "================================================================"
echo "  Done. Results written to: ${OUTPUT_JSON}"
echo "  Raw logs in             : ${RESULTS_DIR}/"
echo "  Completed: $(date -Iseconds)"
if [[ "${GLOBAL_FAIL}" -ne 0 ]]; then
    echo -e "  \e[31mSome verification checks failed — see output above.\e[0m"
fi
echo "================================================================"
