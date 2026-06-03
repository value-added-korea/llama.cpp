# llama.cpp Build Commands — AOCC + AMD Ryzen (Zen4/5)

This document covers building llama.cpp on AMD Ryzen 7000-series (Zen4) and 8000-series (Zen5) with various GPU backends and AOCC 5.2.0 compiler.

**System Configuration (as of 2026-06-03):**
- AOCC 5.2.0 at `/opt/AMD/aocc-compiler-5.2.0`
- ROCM 7.13.0 at `/opt/rocm/core-7.13`
- CUDA 13.3 at `/usr/local/cuda-13.3`
- Target CPU: AMD Ryzen 7 8845HS (`-march=znver4`; use `-march=znver5` for Ryzen 9000-series)

---

## Recommended: CMake Presets

All builds are configured in `CMakePresets.json`. Use presets for the simplest, most maintainable builds:

```bash
# Configure with a preset
cmake -S . --preset <preset-name>

# Build (auto-detects the preset's build directory)
cmake --build build-<preset-name> -j$(nproc)
```

### Available Presets

| Preset | Backend | Description |
|--------|---------|-------------|
| `cpu-aocc` | CPU | CPU-only with AOCC, no GPU |
| `vulkan-aocc` | Vulkan | AMD Radeon 780M iGPU (RADV) |
| `rocm-aocc` | ROCm/HIP | AMD Radeon 780M with ROCm 7.13.0 (HIP) |
| `x64-linux-rocm-release` | ROCm/HIP | Alternative ROCm preset (release build) |
| `x64-linux-rocm-debug` | ROCm/HIP | Alternative ROCm preset (debug symbols) |
| `x64-linux-rocm-reldbg` | ROCm/HIP | Alternative ROCm preset (release + debug) |
| `cuda-aocc-release` | CUDA | NVIDIA RTX 4060 with CUDA 13.3 + AOCC host compiler |
| `cuda-aocc-debug` | CUDA | CUDA with debug symbols |
| `cuda-aocc-reldbg` | CUDA | CUDA with release optimization + debug info |

### Examples

**Build for Vulkan (AMD 780M):**
```bash
cmake -S . --preset vulkan-aocc
cmake --build build-vulkan-aocc -j$(nproc)
```

**Build for CUDA (NVIDIA RTX 4060):**
```bash
cmake -S . --preset cuda-aocc-release
cmake --build build-cuda-aocc-release -j$(nproc)
```

**Build for ROCm/HIP (AMD 780M):**
```bash
cmake -S . --preset rocm-aocc
cmake --build build-rocm-aocc -j$(nproc)
```

**Build for CPU only:**
```bash
cmake -S . --preset cpu-aocc
cmake --build build-cpu-aocc -j$(nproc)
```

---

## Alternative: Manual CMake Commands

If you need to customize beyond what presets offer, use manual cmake commands:

### 1. ROCm + HIP (gfx1103 — AMD Radeon 780M)

```bash
cmake -B build-rocm-aocc \
    -DCMAKE_C_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang++ \
    -DROCM_PATH=/opt/rocm/core-7.13 \
    -DGGML_HIP=ON \
    -DAMDGPU_TARGETS=gfx1103 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3"

cmake --build build-rocm-aocc -j$(nproc)
```

### 2. Vulkan (AMD Radeon 780M iGPU)

```bash
cmake -B build-vulkan-aocc \
    -DCMAKE_C_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang++ \
    -DGGML_VULKAN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3"

cmake --build build-vulkan-aocc -j$(nproc)
```

### 3. CUDA (NVIDIA RTX 4060) with AOCC Host Compiler

```bash
cmake -B build-cuda-aocc-release \
    -G Ninja \
    -DCMAKE_C_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang++ \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.3/bin/nvcc \
    -DCMAKE_CUDA_HOST_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang++ \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=89 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3"

cmake --build build-cuda-aocc-release -j$(nproc)
```

**Note:** Set `PATH` to include CUDA 13.3 bin if nvcc is not on PATH:
```bash
export PATH=/usr/local/cuda-13.3/bin:$PATH
```

### 4. CPU Only

```bash
cmake -B build-cpu-aocc \
    -DCMAKE_C_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/AMD/aocc-compiler-5.2.0/bin/clang++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3"

cmake --build build-cpu-aocc -j$(nproc)
```

---

## Build Artifacts

All builds output to `build-<preset-name>/bin/`:

- **llama-bench** — Benchmarking tool
- **llama-server** — OpenAI-compatible REST API server
- **llama-cli** — Command-line inference
- Other tools: `llama-perplexity`, `llama-quantize`, `llama-imatrix`, etc.

---

## Debugging / Compiler Flags

**For Zen5 (Ryzen 9000-series):** Replace `-march=znver4` with `-march=znver5`

**For debug builds:** Use `-DCMAKE_BUILD_TYPE=Debug` or preset `*-debug`

**For optimization + debug symbols:** Use `RelWithDebInfo` (preset `*-reldbg`)

**Custom optimization:** Pass `-DCMAKE_C_FLAGS` / `-DCMAKE_CXX_FLAGS` with your flags (e.g., `-march=native -O3 -g`)

---

## See Also

- [CLAUDE.md](CLAUDE.md) — Project setup and CI documentation
- [CMakePresets.json](CMakePresets.json) — Full preset definitions
- [docs/build.md](docs/build.md) — Official llama.cpp build documentation
