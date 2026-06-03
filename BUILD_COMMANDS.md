# llama.cpp Build Commands — AOCC + AMD Zen4/Zen5

All builds use AOCC 5.2.0. Replace `-march=znver4` with `-march=znver5` for Zen5 targets.

```bash
ROCM=/opt/rocm/core-7.13
AOCC=/opt/AMD/aocc-compiler-5.2.0
MARCH="-march=znver4 -O3"   # change to znver5 for Zen5
```

---

## 1. ROCm + HIP (GPU — gfx1103)

```bash
ROCM=/opt/rocm/core-7.13
AOCC=/opt/AMD/aocc-compiler-5.2.0

HIPCXX=$ROCM/bin/clang \
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

cmake --build build-rocm-aocc --config Release -j$(nproc)
```


---

## 2. Vulkan (GPU)

```bash
AOCC=/opt/AMD/aocc-compiler-5.2.0

cmake -B build-vulkan-aocc \
    -DCMAKE_C_COMPILER=$AOCC/bin/clang \
    -DCMAKE_CXX_COMPILER=$AOCC/bin/clang++ \
    -DGGML_VULKAN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3" \
    -DOpenMP_C_FLAGS="-fopenmp=libomp -L$AOCC/lib" \
    -DOpenMP_CXX_FLAGS="-fopenmp=libomp -L$AOCC/lib" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-openmp"

cmake --build build-vulkan-aocc --config Release -j$(nproc)
```

---

## 3. CPU only

```bash
AOCC=/opt/AMD/aocc-compiler-5.2.0

cmake -B build-cpu-aocc \
    -DCMAKE_C_COMPILER=$AOCC/bin/clang \
    -DCMAKE_CXX_COMPILER=$AOCC/bin/clang++ \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-march=znver4 -O3" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -O3" \
    -DOpenMP_C_FLAGS="-fopenmp=libomp -L$AOCC/lib" \
    -DOpenMP_CXX_FLAGS="-fopenmp=libomp -L$AOCC/lib" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-openmp"

cmake --build build-cpu-aocc --config Release -j$(nproc)
```
