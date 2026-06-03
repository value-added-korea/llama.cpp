# CLAUDE.md — GPU Device Enforcement Policy

## Hardware Context

| Device | Role | Status |
|--------|------|--------|
| AMD Radeon 780M (RDNA3, gfx1103, PCIe 0x1002:0x1900) | iGPU — PRIMARY TARGET | ALWAYS ACTIVE |
| NVIDIA GeForce RTX 4060 Laptop GPU | dGPU | PERMANENTLY EXCLUDED |
| AMD Ryzen 7 8845HS (Zen 4, 8C/16T) | CPU | ALWAYS ACTIVE |

**The NVIDIA RTX 4060 must never appear in any build, benchmark, inference run, or device enumeration.
Every Vulkan and ROCm operation targets the AMD 780M exclusively.**

---

## CMake Configuration — Required Flags

Every `cmake` configure invocation must include these flags without exception.

### Vulkan + AOCC build
```
-DGGML_CUDA=OFF
-DGGML_VULKAN=ON
-DGGML_HIP=OFF
-DCMAKE_C_COMPILER=amdclang
-DCMAKE_CXX_COMPILER=amdclang++
```

### ROCm + AOCC build
```
-DGGML_CUDA=OFF
-DGGML_VULKAN=OFF
-DGGML_HIP=ON
-DAMDGPU_TARGETS=gfx1103
-DCMAKE_C_COMPILER=amdclang
-DCMAKE_CXX_COMPILER=amdclang++
```

### CPU + AOCC build
```
-DGGML_CUDA=OFF
-DGGML_VULKAN=OFF
-DGGML_HIP=OFF
-DCMAKE_C_COMPILER=amdclang
-DCMAKE_CXX_COMPILER=amdclang++
```

### Prohibited CMake flags — never use
- `-DGGML_CUDA=ON`
- `-DGGML_CUBLAS=ON`
- Any flag referencing `CUDA`, `CUBLAS`, or `NVCC`

---

## Environment Variables — Required Before Any Build or Run

### Vulkan — restrict ICD to AMD RADV only
```
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json
```
This prevents the Vulkan loader from enumerating the NVIDIA device entirely.
Do not add `nvidia_icd.json` or use colon-separated multi-ICD paths.

If the system uses `/etc/vulkan/icd.d/` instead:
```
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/radeon_icd.json
```

### ROCm — restrict to 780M (device 0)
```
export ROCR_VISIBLE_DEVICES=0
export HIP_VISIBLE_DEVICES=0
```
Do NOT set `HSA_OVERRIDE_GFX_VERSION`. The 780M (gfx1103) is natively supported
by ROCm 7.13; overriding the GFX version confuses the driver memory allocator
and causes GPU hangs under llama.cpp workloads.

### Neutralize CUDA / NVIDIA paths
```
export CUDA_VISIBLE_DEVICES=""
unset CUDA_DEVICE_ORDER
```

---

## Pre-Run Verification Sequence

Run these before every benchmark or inference session to confirm device isolation.

### Confirm only AMD 780M is visible to Vulkan
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json vulkaninfo --summary 2>/dev/null | grep -E "deviceName|deviceType"
```
Expected output must contain `AMD Radeon 780M` and must NOT contain `NVIDIA` or `RTX`.

### Confirm ROCm sees only gfx1103
```
ROCR_VISIBLE_DEVICES=0 rocminfo | grep -E "Name:|gfx"
```
Expected: `gfx1103` only.

### Confirm CUDA path is dead
```
nvidia-smi -L 2>/dev/null && echo "NVIDIA VISIBLE — ABORT" || echo "NVIDIA isolated — OK"
```
Expected: `NVIDIA isolated — OK`

---

## llama.cpp Runtime Flags — Vulkan Backend

`VK_ICD_FILENAMES` restricts the Vulkan loader to RADV only, so the AMD 780M is always
device 0 and no NVIDIA device is ever visible. No `--device` selector is needed.

For `llama-server` and `llama-cli` only (not `llama-bench`), you may additionally pass:
```
--device AMD
--main-gpu 0
--n-gpu-layers 999
```
`--device AMD` performs substring match against the device name as a belt-and-suspenders
guard. `llama-bench` does not support name-based `--device` selection; rely on
`VK_ICD_FILENAMES` for isolation there.

---

## ROCm GPU Hang Recovery

If a ROCm workload triggers a `GPU Hang` (`HW Exception by GPU node-X reason: GPU Hang`),
the iGPU is left in a corrupted state for the rest of the session. There is no PCI
reset path for an integrated GPU.

**Recovery:**
```bash
# Option 1: log out and back in (clears the GPU context)
# Option 2: restart the display manager
sudo systemctl restart gdm        # GNOME
sudo systemctl restart lightdm    # LightDM / KDE
```

**Prevention:**
- Always use the dynamic NGL computed by `compute_safe_rocm_ngl()` in `run_bench_compare.sh`
- Never set `ngl=999` manually for models larger than the ROCm VRAM cap (~2 GB on 780M)
- Do NOT set `HSA_OVERRIDE_GFX_VERSION` — it corrupts the driver memory allocator on gfx1103

---

## 780M VRAM Budget

The 780M shares system RAM. Effective usable budget for model weights is **4 GB maximum**.

| GGUF File Size | 780M Offload | Action |
|----------------|-------------|--------|
| ≤ 4 GB | Full (`-ngl 999`) | Safe |
| 4–6 GB | Partial | Set `-ngl` to leave 1–2 GB for KV cache |
| > 6 GB | None | CPU-only inference |

`Q4_K_M` of a 7B model is approximately 4.4–4.7 GB. For full offload on the 780M,
use `Q3_K_M` (≈ 3.6 GB) or `Q4_K_S` (≈ 4.1 GB).

---

## Prohibited Actions — Claude Code Must Never

1. Introduce `-DGGML_CUDA=ON` or any CUDA-enabling CMake flag into any build directory.
2. Set `VK_ICD_FILENAMES` to include `nvidia_icd.json` in any form.
3. Pass `--device NVIDIA`, `--device 1`, or any flag that routes compute to the RTX 4060.
4. Run any binary under the Vulkan build without `VK_ICD_FILENAMES` explicitly set to the RADV ICD.
5. Suggest, scaffold, or generate CUDA kernel code, `.cu` files, or `nvcc` compile commands.
6. Benchmark or profile any configuration that shows `NVIDIA` in device enumeration output.
7. Modify `CMakeLists.txt` or any `cmake/` file in a way that re-enables CUDA detection.

---

## Build Directory Naming Convention

Enforce this naming so device scope is unambiguous:

| Directory | Backend | Compiler |
|-----------|---------|----------|
| `build-cpu-aocc` | CPU | AOCC (amdclang) |
| `build-vulkan-aocc` | Vulkan → AMD 780M | AOCC (amdclang) |
| `build-rocm-aocc` | ROCm → gfx1103 | AOCC (amdclang) |

Any directory named `build-cuda-*` or `build-nvcc-*` must be treated as an error state and flagged for deletion.
