**Hard constraint upfront:** Full static linking of the ROCm stack is not possible. This is architectural, not a build flag issue.

| Library | Static linkable | Reason |
|---------|----------------|--------|
| `libomp.so` (AOCC) | ✅ Yes | Standard static archive available |
| llama.cpp own `.so` | ✅ Yes | `BUILD_SHARED_LIBS=OFF` |
| `libamdhip64.so` | ❌ No | dlopens device firmware at runtime |
| `libhsa-runtime64.so` | ❌ No | Requires `/dev/kfd` + dlopens device-specific code |
| `librocblas.so` | ❌ No | Loads Tensile `.co`/`.hsaco` kernel files from filesystem at runtime via `ROCBLAS_TENSILE_LIBPATH` |

**What you CAN do: bundle with RPATH (the correct distribution approach)**

The binary uses `$ORIGIN`-relative RPATH so it finds bundled `.so` files regardless of what ROCm version (or none) is installed on the target machine.

**Build command:**

```bash
cd ~/git/ROCM_llama-server-gfx1103/llama.cpp

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

cmake --build build-rocm-aocc --config Release -j$(nproc) 2>&1 | tee /tmp/llama-build.log
```

**Collect the bundle:**

```bash
ROCM=/opt/rocm/core-7.13
AOCC=/opt/AMD/aocc-compiler-5.2.0

BUNDLE=/tmp/llama-rocm-gfx1103
BIN=$BUNDLE/usr/lib/llama-rocm/bin
LIB=$BUNDLE/usr/lib/llama-rocm/lib
RB=$BUNDLE/usr/lib/llama-rocm/rocblas

mkdir -p $BIN $LIB $RB

# Binaries
cp build-rocm-aocc/bin/llama-server \
   build-rocm-aocc/bin/llama-bench \
   build-rocm-aocc/bin/llama-cli \
   $BIN/

# ROCm 7.13 runtime .so files
for lib in \
    libhsa-runtime64.so.1 \
    libamdhip64.so \
    librocblas.so \
    libamd_comgr.so \
    libhipblaslt.so \
    libdrm.so.2 \
    libdrm_amdgpu.so.1; do
    cp -L $ROCM/lib/$lib $LIB/ 2>/dev/null || true
done

# AOCC libomp — absent in ldd output if -static-openmp succeeded
cp $AOCC/lib/libomp.so $LIB/ 2>/dev/null || true

# rocBLAS Tensile kernels for gfx1103
cp -r $ROCM/lib/rocblas/library $RB/
# Trim to gfx1103 only to reduce package size
find $RB/library -name "*" ! -name "*gfx1103*" ! -name "*.dat" -delete 2>/dev/null || true

# Verify RPATH is set correctly
readelf -d $BIN/llama-server | grep RPATH
# Expected: Library rpath: [$ORIGIN/../lib]
```

**Create the .deb:**

```bash
mkdir -p $BUNDLE/DEBIAN
cat > $BUNDLE/DEBIAN/control << 'EOF'
Package: llama-rocm-gfx1103
Version: 1.0.0
Architecture: amd64
Maintainer: vai
Depends: libdrm-amdgpu1
Description: llama.cpp built with ROCm 7.13 + AOCC 5.2.0 for AMD gfx1103 (Radeon 780M)
 Bundled ROCm runtime. Does not require ROCm installed on target machine.
EOF

cat > $BUNDLE/DEBIAN/postinst << 'EOF'
#!/bin/bash
ln -sf /usr/lib/llama-rocm/bin/llama-server /usr/local/bin/llama-server-rocm
ln -sf /usr/lib/llama-rocm/bin/llama-bench /usr/local/bin/llama-bench-rocm
EOF
chmod 755 $BUNDLE/DEBIAN/postinst

dpkg-deb --build $BUNDLE /tmp/llama-rocm-gfx1103_1.0.0_amd64.deb
```

**Verify on a clean machine:**

```bash
# Check binary is self-contained
ldd /usr/lib/llama-rocm/bin/llama-server | grep "not found"
# Must return nothing

# Confirm libomp is static (won't appear in ldd)
ldd /usr/lib/llama-rocm/bin/llama-server | grep omp
# Should be absent if -static-openmp worked
```

The only dependency on the target machine is `libdrm-amdgpu1` (in-kernel DRM interface, always present on any system running amdgpu) and the kernel's `/dev/kfd` and `/dev/dri/renderD*` nodes.
