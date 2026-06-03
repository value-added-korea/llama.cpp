# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Policies

**IMPORTANT: Read [AGENTS.md](AGENTS.md) before beginning any work.** This project has strict policies regarding AI assistance:

- **AI-generated pull requests are rejected.** AI tools may only assist with corrections or to expand on changes the contributor has already conceptualized.
- PR descriptions and commit messages written by AI are grounds for immediate closure.
- AI-generated responses to reviewer comments are prohibited.
- First-time contributors must acknowledge this policy before submitting changes.

When assisting, prioritize helping the user understand the codebase and design solutions, rather than implementing changes for them. Always verify they can independently explain and maintain the code before proceeding.

## Project Overview

**llama.cpp** is a C/C++ implementation for LLM inference with minimal dependencies. The project includes:

- **Core library** (`libllama`): C-style API in [include/llama.h](include/llama.h)
- **GGML tensor library**: Neural network backend (in [ggml/](ggml/) subdirectory)
- **Command-line tools**: inference, quantization, benchmarking, conversion
- **llama-server**: OpenAI-compatible REST API server with Web UI
- **Examples and bindings**: Multiple language integrations

## Toolchain Information

**Current System Configuration** (as of 2026-06-01):

- **ROCM Version**: 7.13.0 (Build: 7.13.0.0-9999-3309c611)
- **HIP Version**: 7.13.99004 (Revision: 3309c611)
- **AMD Clang**: 23.0.0git
- **Installation Path**: `/opt/rocm/core-7.13`
- **Compiler Binary**: `/opt/rocm/core-7.13/bin/hipcc` (full path)

**IMPORTANT: HIP Development Environment**

The system has a partial ROCM 7.13.0 installation. To build with HIP acceleration, you need the full development environment:

```bash
# Install missing HIP development packages
sudo apt-get install rocm-hip-dev rocm-hip-devel
```

This installs the hip-lang CMake package required for HIP compilation.

To verify your local toolchain:
```bash
hipcc --version
rocm-smi --version
cat /opt/rocm/core-7.13/include/rocm-core/rocm_version.h
```

## Building

### Basic CMake Build (CPU)

```bash
cmake -B build
cmake --build build --config Release -j 8
```

- Use `-j N` for parallel compilation (adjust N based on cores)
- For debug builds: `cmake -B build -DCMAKE_BUILD_TYPE=Debug`
- For static builds: add `-DBUILD_SHARED_LIBS=OFF`

### GPU Backends

Build documentation in [docs/build.md](docs/build.md) covers CUDA, Metal, HIP, SYCL, Vulkan, and other backends. Most common:

- **NVIDIA GPU (CUDA)**: Add `-DGGML_CUDA=ON`
- **AMD GPU (HIP)**: Add `-DGGML_HIP=ON` (uses ROCM 7.13.0 and AMD Clang 23.0.0 on this system)
- **Intel GPU (SYCL)**: Add `-DGGML_SYCL=ON` (see [docs/backend/SYCL.md](docs/backend/SYCL.md))
- **Mac Metal**: Enabled by default; disable with `-DGGML_METAL=OFF`

### HIP Build Example

To build with AMD GPU support using the installed ROCM toolchain, optimized for **gfx1103** (Ryzen 7040/Phoenix APU):

**Prerequisites:**
First, ensure you have the full HIP development environment installed:
```bash
sudo apt-get install rocm-hip-dev rocm-hip-devel
```

**Using CMake Presets (Recommended):**
All presets are configured with `GPU_TARGETS=gfx1103` for fast, device-specific compilation:
```bash
cmake -S . --preset x64-linux-rocm-release
cmake --build build-x64-linux-rocm-release -j 8
```

**Using AOCC + amdclang++ (Verified Working):**
```bash
AOCC=/opt/AMD/aocc-compiler-5.2.0
ROCM=/opt/rocm/core-7.13

HIPCXX=$ROCM/bin/amdclang++ \
HIP_PATH=$ROCM \
cmake -B build-rocm-aocc \
    -DCMAKE_C_COMPILER=$AOCC/bin/clang \
    -DCMAKE_CXX_COMPILER=$AOCC/bin/clang++ \
    -DROCM_PATH=$ROCM \
    -DGGML_HIP=ON \
    -DAMDGPU_TARGETS=gfx1103 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3" \
    -DOpenMP_C_FLAGS="-fopenmp=libomp -L$AOCC/lib" \
    -DOpenMP_CXX_FLAGS="-fopenmp=libomp -L$AOCC/lib" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-openmp -Wl,-rpath,\$ORIGIN/../lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath,\$ORIGIN/../lib"
cmake --build build-rocm-aocc -j$(nproc)
```

Key points:
- `HIPCXX` must be `amdclang++` (not `clang`) — the HIP compiler lives at `$ROCM/bin/amdclang++`
- C/CXX compilers use AOCC for host code; `amdclang++` handles HIP device code via `HIPCXX`

**For other GPU targets** (requires different hardware):
- `gfx1030`, `gfx1031`: RDNA2 (RX 6500-6800 series)
- `gfx1100`, `gfx1101`: RDNA3 (RX 7000 series)
- `gfx1103`: RDNA3 with cache (Ryzen 7040/Phoenix) - **Default for this system**


The build will automatically use ROCM 7.13.0 and AMD Clang 23.0.0 from `/opt/rocm/core-7.13`.

### Faster Builds

Install [ccache](https://ccache.dev/) for automatic compilation caching. CMake will detect and use it automatically.

## Testing

Run tests after building:

```bash
# Unit tests
ctest --test-dir build

# Specific test
ctest --test-dir build -R test-chat -V
```

**Test directory**: [tests/](tests/) contains unit tests (test-*.cpp). Key tests:

- `test-backend-ops`: Validates different backend implementations produce consistent results
- `test-chat`: Chat template parsing and application
- `test-chat-template`, `test-chat-peg-parser`: Grammar and template parsing

**Performance verification**: After changes affecting inference:

- Use `llama-bench` to check performance impact
- Use `llama-perplexity` to verify model accuracy is unaffected

## CI Locally

To run the full CI workflow locally:

```bash
mkdir tmp_ci
bash ./ci/run.sh ./tmp_ci/results ./tmp_ci/mnt

# With specific backends
GG_BUILD_CUDA=1 bash ./ci/run.sh ./tmp_ci/results ./tmp_ci/mnt

# HIP build with ROCM 7.13.0 and AMD Clang 23.0.0
GG_BUILD_HIP=1 bash ./ci/run.sh ./tmp_ci/results ./tmp_ci/mnt
```

See [ci/README.md](ci/README.md) for details. The HIP build uses the installed ROCM 7.13.0 toolchain.

## Code Architecture

### Core Components

**libllama** (in [src/](src/)):
- `llama-context.h/cpp`: Main inference context management
- `llama-model.h/cpp`: Model loading and initialization
- `llama-batch.h/cpp`: Batch management for parallel inference
- `llama-sampler.h/cpp`: Token sampling implementations
- `llama-chat.h/cpp`: Chat template parsing and application
- `llama-grammar.h/cpp`: BNF grammar constraints
- `llama-arch.h/cpp`: Model architecture definitions

**GGML tensor library** (in [ggml/](ggml/)):
- Core tensor operations and computational graph
- Backend implementations (CPU, CUDA, Metal, etc.)
- Ops like matrix multiplication, element-wise operations

### Tools and Examples

[tools/](tools/) directory contains specialized tools:

- **server**: OpenAI-compatible REST API and Web UI ([tools/server/](tools/server/))
- **cli**: Command-line inference interface
- **bench**: Performance benchmarking (`llama-bench`)
- **perplexity**: Model evaluation
- **quantize**: Model quantization
- **gguf-split**: GGUF file utilities
- **imatrix**: Importance matrix computation for quantization

### llama-server Architecture

Key files in [tools/server/](tools/server/):

- `server.cpp`: Main HTTP server implementation
- `server_context.h/cpp`: Core inference state and slot management
- `server_routes.h/cpp`: HTTP endpoints and routing middleware
- `server_queue.h/cpp`: Thread-safe task queue
- `server_response.h/cpp`: Response queue
- `server_slot.h/cpp`: Per-request inference slot abstraction
- `server_models.h/cpp`: Multi-model management (router mode)

Development documentation: [tools/server/README-dev.md](tools/server/README-dev.md) - read this before implementing server features.

**Server scope** (from README-dev.md):
- In-scope: chat completion, tool calling, embeddings, model management, multimodal support, memory/state management
- Out-of-scope: server-side agentic loops (use external APIs), model-specific features, plugin systems

## Coding Standards

### C/C++ Style

- No modern STL constructs; use basic `for` loops instead of range-based patterns where possible
- Keep it simple; avoid templates where possible
- Use sized integer types (`int32_t`, `uint64_t`, etc.) in public APIs
- Snake case for functions, variables, types: `llama_model_init()`, `context_idx`
- Enum values: uppercase with enum prefix: `LLAMA_VOCAB_TYPE_SPM`
- Naming pattern: `<class>_<action>_<noun>` (e.g., `llama_sampler_get_seed`)
- Struct declarations without `typedef`: `struct foo { ... }`
- Clang-format with [.clang-format](.clang-format) in repo root (run: `clang-format -i file.cpp`)
- 4-space indentation, no trailing whitespace
- Vertical alignment for readability

### Comments

- Minimal comments; code should be self-explanatory through naming
- Only comment WHY, not WHAT: hidden constraints, subtle invariants, workarounds
- Don't reference the current task or callers in code comments

### Dependencies

- Avoid third-party dependencies; use only system libraries
- Cross-platform compatibility required (Windows, macOS, Linux, mobile)
- No C++17+ features in core library; keep baseline compatibility

### Tensor Operations

- Tensors stored in row-major order; dimension 0 = columns, 1 = rows, 2 = matrices
- Matrix multiplication is unconventional: `C = ggml_mul_mat(ctx, A, B)` means $C^T = A B^T$

## Adding New Models

See [docs/development/HOWTO-add-model.md](docs/development/HOWTO-add-model.md).

**Summary**: Model support means adding architecture detection and layer implementations. Focus on CPU support in the initial PR; add GPU backend support in follow-ups.

## Adding New Quantization Types

Requires additional evidence (from [CONTRIBUTING.md](CONTRIBUTING.md)):

- Convert a small model to GGUF using the new type and upload to HuggingFace
- Provide perplexity comparisons vs. FP16/BF16
- Provide KL divergence data vs. FP16/BF16 for multiple types
- Provide performance benchmarks on pure CPU for comparable types

## Documentation

- [docs/](docs/) directory for user-facing docs
- API reference in header files ([include/llama.h](include/llama.h))
- When fixing unclear APIs, add a summary comment to the header
- Update existing docs if they're outdated

## Key Resources

- [AGENTS.md](AGENTS.md): AI usage policy
- [CONTRIBUTING.md](CONTRIBUTING.md): Full contributor guidelines
- [build.md](docs/build.md): Build system for all backends
- [tools/server/README-dev.md](tools/server/README-dev.md): Server development
- [ggml-org/ggml](https://github.com/ggml-org/ggml): Core tensor library (check examples/simple, examples/gpt-2)
- [docs/ops.md](docs/ops.md): Tensor operations reference
- [PEG parser](docs/development/parsing.md): Grammar parsing used by llama.cpp
- [Auto parser](docs/autoparser.md): Higher-level parser
- [Jinja engine](common/jinja/README.md): Chat template implementation
- [PR template](.github/pull_request_template.md): Standard PR format

## Before Submitting Code

1. **Understand the change**: You must be able to explain every line of code you submit
2. **Test locally**: Run `ctest --test-dir build` and verify no regressions
3. **Performance**: Use `llama-bench` and `llama-perplexity` if affecting inference
4. **Backend consistency**: Run `test-backend-ops` if modifying tensor operations
5. **Search existing issues/PRs**: Avoid duplicate effort
6. **CI locally**: Run `bash ./ci/run.sh ...` before publishing
7. **Scope properly**: One feature per PR; avoid mixing unrelated changes
8. **Start with CPU**: For new models/features, CPU support first, GPU backends in follow-ups
9. **Search CODEOWNERS**: Find code owners for your area if adding/modifying significant code
10. **Disclose AI usage**: If AI contributed meaningfully, state this and include your personal review

## Module Naming

Module prefixes for commit messages are at [llama.cpp wiki Modules](https://github.com/ggml-org/llama.cpp/wiki/Modules).
