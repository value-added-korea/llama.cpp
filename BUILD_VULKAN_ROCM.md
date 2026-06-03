# Building llama.cpp with Vulkan and ROCM

This guide provides step-by-step instructions for building llama.cpp with GPU acceleration using either Vulkan or AMD ROCM backends. Choose the section that matches your hardware and operating system.

---

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Vulkan Build](#vulkan-build)
3. [ROCM/HIP Build](#rocmhip-build)
4. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Common Requirements

- CMake 3.14 or newer
- A C/C++ compiler (GCC, Clang, or MSVC)
- Git

### For Vulkan Builds

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get update
sudo apt-get install cmake git build-essential libvulkan-dev glslc spirv-headers
```

**Linux (Fedora/RHEL/openSUSE):**
```bash
sudo dnf install cmake git gcc g++ vulkan-devel spirv-headers glslc
# or for openSUSE:
sudo zypper install cmake git gcc g++ vulkan-devel spirv-headers glslc
```

**Linux (Arch/Manjaro):**
```bash
sudo pacman -S cmake git base-devel vulkan-devel spirv-headers glslc
```

**Windows (w64devkit method):**
1. Download and extract [w64devkit](https://github.com/skeeto/w64devkit/releases)
2. Download [Vulkan SDK](https://vulkan.lunarg.com/sdk/home#windows) and install with default settings
3. From w64devkit, copy Vulkan dependencies to your devkit installation directory

**Windows (MSYS2):**
```bash
pacman -S git \
    mingw-w64-ucrt-x86_64-gcc \
    mingw-w64-ucrt-x86_64-cmake \
    mingw-w64-ucrt-x86_64-vulkan-devel \
    mingw-w64-ucrt-x86_64-shaderc \
    mingw-w64-ucrt-x86_64-spirv-headers
```

**macOS:**
- Download and install [Vulkan SDK](https://vulkan.lunarg.com/sdk/home#mac)
- Check "KosmicKrisp" during installation
- Set environment variable: `source /path/to/vulkan-sdk/setup-env.sh`

### For ROCM/HIP Builds

**Linux (any distro with ROCM support):**

Installation depends on your distro. Check [ROCm Installation Guide](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/tutorial/quick-start.html#rocm-install-quick).

After ROCM is installed, verify with:
```bash
hipcc --version
rocm-smi --version
```

**Current System Configuration (this repository):**
- ROCM 7.13.0 installed at `/opt/rocm/core-7.13`
- HIP 7.13.99004
- AMD Clang 23.0.0

To install full HIP development support (required for complete builds):
```bash
sudo apt-get install rocm-hip-dev rocm-hip-devel
```

---

## Vulkan Build

### Linux (Ubuntu/Debian)

#### Using CMake Presets (Recommended)

Pre-configured for AMD Radeon 780M iGPU:

**Release build:**
```bash
cd llama.cpp
cmake -S . --preset x64-linux-vulkan-release
cmake --build build-x64-linux-vulkan-release -j 8
```

**Debug build:**
```bash
cmake -S . --preset x64-linux-vulkan-debug
cmake --build build-x64-linux-vulkan-debug -j 8
```

View available presets:
```bash
cmake --list-presets 2>&1 | grep vulkan
```

#### Manual CMake Build

**Basic build:**
```bash
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j 8
```

**With optimization:**
```bash
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j 8
```

**Static build (for distribution):**
```bash
cmake -B build -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build --config Release -j 8
```

#### Verify Vulkan Detection

```bash
./build/bin/llama-cli -m "path/to/model.gguf" -p "Hello" -ngl 99
```

Look for Vulkan output like: `ggml_vulkan: Using AMD Radeon 780M ... | uma: 1 | fp16: 1`

---

### Linux (Fedora/RHEL/openSUSE)

```bash
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j 8
```

---

### macOS (with Vulkan SDK)

#### Using MoltenVK (default)
```bash
source /path/to/vulkan-sdk/setup-env.sh
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j 8
```

#### Using KosmicKrisp (alternative)
```bash
export VK_ICD_FILENAMES=$VULKAN_SDK/share/vulkan/icd.d/libkosmickrisp_icd.json
export VK_DRIVER_FILES=$VULKAN_SDK/share/vulkan/icd.d/libkosmickrisp_icd.json
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release -j 8
```

---

### Windows (w64devkit)

In w64devkit terminal:
```bash
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release
```

Test with:
```bash
build\bin\Release\llama-cli -m "path\to\model.gguf" -p "Hello" -ngl 99
```

---

### Windows (Git Bash MINGW64)

```bash
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release
```

Test with:
```bash
./build/bin/Release/llama-cli -m "path/to/model.gguf" -p "Hello" -ngl 99
```

---

### Windows (MSYS2)

From UCRT terminal:
```bash
cd llama.cpp
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release
```

---

### Docker (Linux)

No need to install Vulkan SDK:
```bash
docker build -t llama-cpp-vulkan --target light -f .devops/vulkan.Dockerfile .

# Run with GPU support
docker run -it --rm -v "$(pwd):/app:Z" \
    --device /dev/dri/renderD128:/dev/dri/renderD128 \
    --device /dev/dri/card1:/dev/dri/card1 \
    llama-cpp-vulkan -m "/app/models/YOUR_MODEL_FILE" -p "Hello" -n 400 -ngl 33
```

---

## ROCM/HIP Build

### Prerequisites

Ensure ROCM is properly installed and configured:

```bash
# Verify ROCM installation
hipcc --version
rocm-smi --version

# Check version file
cat /opt/rocm/core-7.13/include/rocm-core/rocm_version.h
```

### Linux - Using CMake Presets (Recommended)

The repository includes pre-configured CMake presets for ROCM 7.13.0 optimized for **gfx1103** (Ryzen 7040 / Phoenix APU). All ROCM builds automatically compile with `-DGPU_TARGETS=gfx1103` for fast, device-specific compilation.

#### Release build (Recommended)
```bash
cd llama.cpp
cmake -S . --preset x64-linux-rocm-release
cmake --build build-x64-linux-rocm-release -j 8
```

Preset includes:
- ROCM 7.13.0 at `/opt/rocm/core-7.13`
- AMD Clang 23.0.0 compiler
- **GPU_TARGETS=gfx1103** (Ryzen 7040/Phoenix APU)
- Release optimization (-O3)

#### Debug build
```bash
cd llama.cpp
cmake -S . --preset x64-linux-rocm-debug
cmake --build build-x64-linux-rocm-debug -j 8
```

#### RelWithDebInfo build
```bash
cd llama.cpp
cmake -S . --preset x64-linux-rocm-reldbg
cmake --build build-x64-linux-rocm-reldbg -j 8
```

View available presets:
```bash
cmake --list-presets 2>&1 | grep rocm
```

Output should show:
```
"x64-linux-rocm-debug"              - Linux x64 ROCM 7.13.0 Debug (gfx1103)
"x64-linux-rocm-release"            - Linux x64 ROCM 7.13.0 Release (gfx1103)
"x64-linux-rocm-reldbg"             - Linux x64 ROCM 7.13.0 RelWithDebInfo (gfx1103)
```

---

### Linux - Manual CMake Build

#### Standard build with ROCM 7.13.0 (default: gfx1103)
```bash
cmake -B build \
    -DGGML_HIP=ON \
    -DROCM_PATH=/opt/rocm/core-7.13 \
    -DGPU_TARGETS=gfx1103 \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build --config Release -j 8
```

The `GPU_TARGETS=gfx1103` is optimized for Ryzen 7040 series and Phoenix APU. **This is the recommended build for this system.**

#### Using environment variables
```bash
export ROCM_PATH=/opt/rocm/core-7.13
cmake -B build \
    -DGGML_HIP=ON \
    -DGPU_TARGETS=gfx1103 \
    -DCMAKE_BUILD_TYPE=Release
cmake --build build -j 8
```

#### For different GPU target (requires recompilation)
If you have a different AMD GPU, replace `gfx1103` with your target:
- `gfx1030`, `gfx1031`, `gfx1032`: RDNA2 (RX 6000 series)
- `gfx1100`, `gfx1101`, `gfx1102`: RDNA3 (RX 7000 series)
- `gfx1103`: RDNA3 with cache (Ryzen 7040/Phoenix - **Default for this system**)

```bash
cmake -B build \
    -DGGML_HIP=ON \
    -DROCM_PATH=/opt/rocm/core-7.13 \
    -DGPU_TARGETS=gfx1030 \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build -j 8
```

#### Alternative: hipcc direct compiler approach
```bash
cmake -B build \
    -DGGML_HIP=ON \
    -DROCM_PATH=/opt/rocm/core-7.13 \
    -DGPU_TARGETS=gfx1103 \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=/opt/rocm/core-7.13/bin/hipcc \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build -j 8
```

---

### Linux - Using CI Build Script

```bash
cd llama.cpp
mkdir -p tmp_ci
GG_BUILD_HIP=1 bash ./ci/run.sh ./tmp_ci/results ./tmp_ci/mnt
```

This uses the full CI pipeline with ROCM 7.13.0 and AMD Clang 23.0.0.

---

### Linux - With rocWMMA for Enhanced Flash Attention (gfx1103 recommended)

Flash attention is supported on gfx1103 via the standard HIP path:

```bash
cmake -B build \
    -DGGML_HIP=ON \
    -DROCM_PATH=/opt/rocm/core-7.13 \
    -DGPU_TARGETS=gfx1103 \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build -j 8
```


---

### Build Output and Verification

After a successful build, verify HIP detection:

```bash
# Check what GPU targets were compiled
./build/bin/llama-cli -m "path/to/model.gguf" -p "Hello" -ngl 99
```

Look for output containing HIP/GPU information.

### Using GPU with inference

Set environment variable to specify which GPU to use:

```bash
# Use specific GPU (0-indexed)
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-cli -m "model.gguf" -ngl 99

# Hide first GPU, use all others
HIP_VISIBLE_DEVICES="-0" ./build/bin/llama-cli -m "model.gguf" -ngl 99
```

For unsupported GPU models, try:
```bash
# Override GPU version (e.g., 11.0.0 for RDNA3)
HSA_OVERRIDE_GFX_VERSION=11.0.0 ./build/bin/llama-cli -m "model.gguf" -ngl 99
```

**Note:** `HSA_OVERRIDE_GFX_VERSION` is not supported on Windows.

---

## Troubleshooting

### Vulkan

**Issue:** "vulkaninfo" command not found
- **Solution:** The Vulkan SDK is not in your PATH. Re-run the SDK setup script or add it to your PATH.

**Issue:** Build fails with "Cannot find glslc"
- **Solution:** Install spirv-tools or spirv-headers package for your distro, or configure Vulkan SDK properly.

**Issue:** GPU not detected despite successful build
- **Solution:** Verify Vulkan support with `vulkaninfo` and check driver compatibility for your GPU.

---

### ROCM/HIP

**Issue:** CMake error "hip-lang-config.cmake not found"
- **Cause:** HIP development packages not installed
- **Solution:** Install full development packages:
  ```bash
  sudo apt-get install rocm-hip-dev rocm-hip-devel
  ```

**Issue:** "ROCm root directory does not contain HIP runtime CMake package"
- **Solution:** Ensure ROCM_PATH points to the correct installation directory where hip-lang-config.cmake exists

**Issue:** "cannot find ROCm device library"
- **Workaround:** Specify device library path:
  ```bash
  export HIP_DEVICE_LIB_PATH=/opt/rocm/core-7.13/lib/amdgcn/bitcode
  cmake -B build -DGGML_HIP=ON
  ```

**Issue:** GPU architecture not recognized (gfx1103, etc.)
- **Workaround:** Use environment variable to override GPU version:
  ```bash
  export HSA_OVERRIDE_GFX_VERSION=11.0.0
  ```

**Issue:** Compilation very slow
- **Solution:** Install ccache for faster rebuilds:
  ```bash
  sudo apt-get install ccache
  ```

**Issue:** Permission denied when running llama-cli
- **Solution:** Build binary should be executable. Set permissions:
  ```bash
  chmod +x ./build/bin/llama-cli
  ```

---

## Performance Tips

### Parallel Compilation

Use multiple job threads to speed up builds:

```bash
cmake --build build -j $(nproc)  # Use all available CPU cores
```

### Caching with ccache

Enable automatic compilation caching (works with all backends):

```bash
sudo apt-get install ccache
cmake -B build -DGGML_VULKAN=ON  # ccache auto-detected
cmake --build build -j $(nproc)
```

### Static vs Dynamic Libraries

**Dynamic (default, faster compilation):**
```bash
cmake -B build -DGGML_VULKAN=ON
```

**Static (for portability, slower compilation):**
```bash
cmake -B build -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=OFF
```

### GPU Memory Management

For ROCM, control GPU memory usage at runtime:

```bash
HIP_VISIBLE_DEVICES=0 ./build/bin/llama-cli -m "model.gguf" -ngl 99
```

Use `-ngl N` to specify how many GPU layers to offload (99 = all layers).

---

## Additional Resources

- **CLAUDE.md** - Detailed project documentation and architecture
- **docs/build.md** - Official build documentation
- **tools/server/README-dev.md** - llama-server development guide
- [ROCm Official Documentation](https://rocm.docs.amd.com/)
- [Vulkan SDK](https://vulkan.lunarg.com/)
- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)

---

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review **CLAUDE.md** for project-specific guidance
3. Check existing GitHub issues for your error message
4. Ensure all dependencies are installed (see [System Requirements](#system-requirements))
5. Verify your GPU driver is up-to-date and compatible
