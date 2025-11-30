# PyTorch 2.7.1 Upgrade Impact Analysis for Direct3D-S2

## Problem Statement
**Current Error**: `RuntimeError: CUDA error: no kernel image is available for execution on the device`
- RTX 5090 has compute capability **sm_120** (CUDA 12.0)
- Current PyTorch 2.5.1 only supports up to **sm_90**
- CUDA kernels fail to execute on the RTX 5090

## TRELLIS Solution (Working on RTX 5090)
```dockerfile
FROM pytorch/pytorch:2.7.1-cuda12.8-cudnn9-devel
RUN pip install --index-url https://download.pytorch.org/whl/cu128 \
    torch==2.7.1+cu128 \
    torchvision==0.22.1+cu128 \
    torchaudio==2.7.1+cu128
ENV TORCH_CUDA_ARCH_LIST="12.0"
```

## Direct3D-S2 Current Stack
```
PyTorch:      2.5.1+cu121
torchvision:  0.20.1+cu121
CUDA:         12.1
xformers:     0.0.29.post1
flash_attn:   2.8.3
triton:       3.1.0
torchsparse:  2.1.0 (custom CUDA extension)
```

## Critical Dependencies Analysis

### ✅ SAFE TO UPGRADE
1. **flash-attn** (2.8.3)
   - Compatible with PyTorch 2.7.1
   - Will work fine, may even get performance improvements

2. **triton** (3.1.0)
   - PyTorch 2.7.1 comes with compatible triton
   - Should work without issues

3. **utils3d** (git install)
   - Pure Python or flexible CUDA code
   - No version constraints

4. **Standard packages** (numpy, trimesh, diffusers, etc.)
   - No PyTorch version dependencies
   - Safe

### ⚠️ NEEDS RECOMPILATION
1. **torchsparse** (2.1.0)
   - Custom CUDA extension built against PyTorch 2.5.1
   - **MUST be recompiled** with TORCH_CUDA_ARCH_LIST="12.0"
   - Risk: Medium (already compiling from source in Dockerfile)
   - Mitigation: Keep existing build process, just change env var

2. **third_party/voxelize** (udf_ext)
   - Uses `torch.utils.cpp_extension.CUDAExtension`
   - **MUST be recompiled** with sm_120 support
   - Risk: Low (already rebuilding at container start in docker-compose.yml)
   - Mitigation: Already handled by docker-compose startup command

### ❌ POTENTIAL ISSUES
1. **xformers** (0.0.29.post1)
   - Currently installed from PyTorch 2.5.1+cu121
   - May have version conflicts with PyTorch 2.7.1
   - **Risk**: High - xformers is notoriously version-sensitive
   - **Mitigation Options**:
     a. Remove xformers (TRELLIS doesn't use it)
     b. Install latest xformers compatible with 2.7.1
     c. Try keeping it and see if it works

2. **transformers** (4.40.2)
   - Fixed version requirement
   - Should work but needs testing
   - Risk: Low

## Proposed Surgical Changes

### Option 1: TRELLIS-Style (Recommended)
**Changes to Dockerfile**:
1. Change line 88:
   ```dockerfile
   # BEFORE
   RUN pip install torch==2.5.1 torchvision==0.20.1 xformers --index-url https://download.pytorch.org/whl/cu121

   # AFTER
   RUN pip install torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cu128
   ```

2. Change line 50:
   ```dockerfile
   # BEFORE
   ENV TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5;8.0;8.6;8.9;9.0"

   # AFTER
   ENV TORCH_CUDA_ARCH_LIST="12.0"
   ```

3. Change line 80 (update CUDA conda package):
   ```dockerfile
   # BEFORE
   RUN conda install cuda -c nvidia/label/cuda-12.1.0 -y

   # AFTER
   RUN conda install cuda -c nvidia/label/cuda-12.8.0 -y
   ```

4. REMOVE xformers from line 88 (not needed, causes conflicts)

**Pros**:
- Matches proven TRELLIS solution
- Minimal changes
- xformers removed (less compatibility issues)

**Cons**:
- Requires full rebuild
- xformers removal may affect performance (unknown impact)

### Option 2: Conservative (Minimal Risk)
Keep PyTorch 2.5.1 but try to force sm_120 compilation with PTX:
```dockerfile
ENV TORCH_CUDA_ARCH_LIST="9.0+PTX"
```

**Pros**:
- No package version changes
- Smaller rebuild scope

**Cons**:
- PTX JIT compilation is SLOW at runtime
- May still fail for some operations
- Not a proper fix, just a workaround

## Rebuild Impact Estimation

### What will rebuild:
1. ✅ PyTorch download: ~2GB, ~3-5 minutes
2. ✅ torchvision download: ~500MB, ~1 minute
3. ✅ flash-attn: Already being built, ~5-10 minutes
4. ✅ torchsparse: Already being built, ~10-15 minutes
5. ✅ voxelize: Rebuilt at container start, ~2 minutes

**Total rebuild time**: ~20-30 minutes (on your 12-core system)

### What won't rebuild:
- Conda installation
- System packages
- Pure Python dependencies
- Git clones

## Recommendation

**I recommend Option 1** (TRELLIS-style upgrade) because:

1. ✅ **Proven solution**: TRELLIS works perfectly with your RTX 5090
2. ✅ **Clean approach**: Removes xformers compatibility issues
3. ✅ **Future-proof**: PyTorch 2.7.1 is latest stable with sm_120 support
4. ✅ **Acceptable rebuild time**: 20-30 minutes with your hardware
5. ✅ **Surgical changes**: Only 3 lines in Dockerfile + remove xformers

## Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| torchsparse build fails | Low | High | Keep existing build error handling (`|| echo "..."`) |
| flash-attn incompatibility | Very Low | Medium | Already has fallback in Dockerfile |
| transformers version conflict | Low | Medium | May need to update to 4.46+ if issues |
| voxelize rebuild fails | Very Low | High | Already handled by docker-compose startup |
| Unknown Direct3D-S2 features break | Medium | High | Test thoroughly after rebuild |

## Testing Plan After Rebuild

1. Container starts successfully
2. Import all packages: `torch`, `torchsparse`, `flash_attn`, `direct3d_s2`
3. CUDA detection: Verify RTX 5090 recognized without warnings
4. Process test image through full pipeline
5. Verify 3D mesh generation works end-to-end

## Decision Required

**Question for user**: Do you want to proceed with Option 1 (TRELLIS-style PyTorch 2.7.1 upgrade)?

- ✅ Yes → Apply surgical changes and rebuild (~30 min)
- ❌ No → Explore alternative solutions (PTX workaround, find prebuilt wheels, etc.)
